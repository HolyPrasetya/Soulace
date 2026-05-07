//
//  CallViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

//
//  CallViewModel.swift
//  Soulace
//

import Foundation
import Combine
import AVFoundation
import UIKit
import FirebaseFirestore

final class CallViewModel: ObservableObject {

    // MARK: - Published State
    @Published var participants: [CallParticipant]     = []
    @Published var waitingEntries: [WaitingEntry]      = []
    @Published var isJoined: Bool                      = false
    @Published var isMuted: Bool                       = false
    @Published var isCameraOff: Bool                   = false
    @Published var sessionElapsed: Int                 = 0
    @Published var sessionRemaining: Int               = 0
    @Published var showVideoPlayer: Bool               = false
    @Published var isVideoPlaying: Bool                = false
    @Published var showParticipantsPanel: Bool         = false
    @Published var showAdmitSheet: Bool                = false
    @Published var pendingEntry: WaitingEntry?         = nil
    @Published var errorMessage: String?               = nil
    @Published var isSessionEnded: Bool                = false
    @Published var isTimerRunning: Bool                = false
    @Published var navigateHome: Bool                  = false
    @Published var syncedVideo: VideoContent?          = nil
    @Published var syncedPosition: Double              = 0
    @Published var syncedIsPlaying: Bool               = false
    @Published var lastSyncTimestamp: Date             = Date()
    @Published var resolvedParticipants: [SoulaceUser] = []
    @Published var finalSummary: SessionSummary?       = nil

    var selectedVideo: VideoContent?

    let session: YogaSession
    let currentUser: SoulaceUser

    private let agoraService     = AgoraService.shared
    private let firestoreService = FirestoreService.shared
    private var cancellables     = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var backgroundEnteredAt: Date?                   = nil
    private var backgroundObservers: [NSObjectProtocol]      = []
    private var lastElapsedSync: Date                        = Date()
    private var participantJoinTimes: [String: Date]         = [:]
    private var resolvedUsersByAgoraUID: [UInt: SoulaceUser] = [:]
    private var resolveTasks: [UInt: Task<Void, Never>]      = [:]

    var isHost: Bool         { session.hostID == currentUser.id }
    var durationSeconds: Int { session.durationMinutes * 60 }
    var elapsedFormatted: String   { formatTime(sessionElapsed) }
    var remainingFormatted: String { formatTime(max(0, durationSeconds - sessionElapsed)) }
    var participantCount: Int      { participants.count + 1 }

    // ✅ Stable UID — deterministik antar device (djb2 hash)
    static func stableUID(from userID: String) -> UInt {
        var hash: UInt64 = 5381
        for byte in userID.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(byte) }
        return UInt(hash % 99_999) + 1
    }

    init(session: YogaSession, currentUser: SoulaceUser, video: VideoContent? = nil) {
        self.session          = session
        self.currentUser      = currentUser
        self.selectedVideo    = video
        self.sessionElapsed   = session.elapsedSeconds
        self.sessionRemaining = max(0, session.durationMinutes * 60 - session.elapsedSeconds)
        observeAgora()
    }

    // MARK: - Observe Agora
    private func observeAgora() {
        agoraService.$remoteParticipants
            .receive(on: DispatchQueue.main)
            .assign(to: &$participants)

        agoraService.$isMuted
            .receive(on: DispatchQueue.main)
            .assign(to: &$isMuted)

        agoraService.$isCameraOff
            .receive(on: DispatchQueue.main)
            .assign(to: &$isCameraOff)

        agoraService.$isJoined
            .receive(on: DispatchQueue.main)
            .sink { [weak self] joined in
                self?.isJoined = joined
                if joined { self?.startTimer() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Join Call
    func joinCall() {
        guard let userID = currentUser.id else { return }
        let uid = CallViewModel.stableUID(from: userID)
        print("📡 My stableUID: \(uid) from \(userID)")

        participantJoinTimes[userID] = Date()

        agoraService.onRemoteUserJoined = { [weak self] agoraUID in
            self?.resolveParticipantName(agoraUID: agoraUID)
        }

        agoraService.joinChannel(session.agoraChannelName, userID: uid)

        Task {
            try? await firestoreService.addParticipantToSession(
                sessionID: session.id ?? "", userID: userID)
            try? await firestoreService.updateSessionStatus(
                id: session.id ?? "", status: .live)
        }

        if isHost { observeWaitingRoom() }
        observeSessionSync()
    }

    // MARK: - Session Sync (video + elapsed)
    private func observeSessionSync() {
        guard let sessionID = session.id else { return }
        firestoreService.observeSession(id: sessionID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] freshSession in
                      guard let self, let fresh = freshSession else { return }
                      self.handleVideoSync(fresh.videoSync)
                      if !self.isHost {
                          let diff = abs(fresh.elapsedSeconds - self.sessionElapsed)
                          if diff > 5 {
                              self.sessionElapsed   = fresh.elapsedSeconds
                              self.sessionRemaining = max(0, self.durationSeconds - fresh.elapsedSeconds)
                          }
                      }
                      for pid in fresh.participantIDs {
                          if self.participantJoinTimes[pid] == nil {
                              self.participantJoinTimes[pid] = Date()
                          }
                      }
                  })
            .store(in: &cancellables)
    }

    // MARK: - Video Sync
    private func handleVideoSync(_ sync: VideoSyncState?) {
        guard let sync else {
            if syncedVideo != nil { syncedVideo = nil; syncedIsPlaying = false }
            return
        }
        if sync.updatedBy == currentUser.id { return }
        guard Date().timeIntervalSince(sync.updatedAt.dateValue()) < 5 else { return }
        if syncedVideo?.id != sync.videoID {
            if let video = firestoreService.getMockVideos().first(where: { $0.id == sync.videoID }) {
                syncedVideo = video; selectedVideo = video
            }
        }
        syncedPosition = sync.position
        syncedIsPlaying = sync.isPlaying
        lastSyncTimestamp = Date()
    }

    func selectAndSyncVideo(_ video: VideoContent) {
        selectedVideo = video; syncedVideo = video; syncedIsPlaying = true
        broadcastVideoState(video: video, isPlaying: true, position: 0)
    }
    func syncPlayPause(isPlaying: Bool, position: Double) {
        syncedIsPlaying = isPlaying
        broadcastVideoState(video: syncedVideo ?? selectedVideo, isPlaying: isPlaying, position: position)
    }
    func syncSeek(to position: Double) {
        broadcastVideoState(video: syncedVideo ?? selectedVideo, isPlaying: syncedIsPlaying, position: position)
    }
    var videoIsLocked: Bool { syncedVideo?.id != nil }
    func closeVideo() {
        selectedVideo = nil; syncedVideo = nil; syncedIsPlaying = false
        guard let sessionID = session.id else { return }
        Task { try? await firestoreService.clearVideoSync(sessionID: sessionID) }
    }
    private func broadcastVideoState(video: VideoContent?, isPlaying: Bool, position: Double) {
        guard let video, let videoID = video.id,
              let sessionID = session.id, let userID = currentUser.id else { return }
        let sync = VideoSyncState(
            videoID: videoID, isPlaying: isPlaying, position: position,
            updatedAt: Timestamp(date: Date()), updatedBy: userID)
        Task { try? await firestoreService.updateVideoSync(sessionID: sessionID, sync: sync) }
    }

    // MARK: - Timer
    func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        registerBackgroundObservers()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.sessionElapsed   += 1
                self.sessionRemaining  = max(0, self.durationSeconds - self.sessionElapsed)
                if self.isHost {
                    let now = Date()
                    if now.timeIntervalSince(self.lastElapsedSync) >= 10 {
                        self.lastElapsedSync = now
                        Task { try? await self.firestoreService.updateSessionElapsed(
                            sessionID: self.session.id ?? "", elapsed: self.sessionElapsed) }
                    }
                }
                if self.sessionRemaining == 0 {
                    self.sessionTimer?.invalidate()
                    self.isTimerRunning = false
                    self.endSession()
                }
            }
        }
        RunLoop.main.add(sessionTimer!, forMode: .common)
    }

    private func registerBackgroundObservers() {
        backgroundObservers.forEach { NotificationCenter.default.removeObserver($0) }
        backgroundObservers.removeAll()
        let enterBg = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.backgroundEnteredAt = Date() }
        let enterFg = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, let bgDate = self.backgroundEnteredAt else { return }
            let elapsed = Int(Date().timeIntervalSince(bgDate))
            self.backgroundEnteredAt  = nil
            self.sessionElapsed       = min(self.sessionElapsed + elapsed, self.durationSeconds)
            self.sessionRemaining     = max(0, self.durationSeconds - self.sessionElapsed)
        }
        backgroundObservers = [enterBg, enterFg]
    }

    func pauseTimer() {
        sessionTimer?.invalidate(); sessionTimer = nil; isTimerRunning = false
        backgroundObservers.forEach { NotificationCenter.default.removeObserver($0) }
        backgroundObservers.removeAll()
    }
    func toggleTimer() { if isTimerRunning { pauseTimer() } else { startTimer() } }

    // MARK: - Navigation
    func goHome() {
        if isHost {
            Task { try? await firestoreService.updateSessionElapsed(
                sessionID: session.id ?? "", elapsed: sessionElapsed) }
        }
        DispatchQueue.main.async { self.navigateHome = true }
    }

    // MARK: - End Call
    func leaveCall() {
        pauseTimer()
        let elapsedSnapshot = sessionElapsed
        Task {
            if isHost {
                try? await firestoreService.updateSessionElapsed(
                    sessionID: session.id ?? "", elapsed: elapsedSnapshot)
                try? await firestoreService.updateSessionStatus(
                    id: session.id ?? "", status: .completed)
            }
            await waitForAllResolveTasks()
            await MainActor.run {
                self.buildResolvedParticipants(elapsedSnapshot: elapsedSnapshot)
                self.finalSummary   = self.buildSummary()
                self.isSessionEnded = true
            }
            agoraService.leaveChannel()
        }
    }

    private func endSession() {
        let elapsedSnapshot = sessionElapsed
        Task {
            if isHost {
                try? await firestoreService.updateSessionElapsed(
                    sessionID: session.id ?? "", elapsed: elapsedSnapshot)
                try? await firestoreService.updateSessionStatus(
                    id: session.id ?? "", status: .completed)
            }
            await waitForAllResolveTasks()
            await MainActor.run {
                self.buildResolvedParticipants(elapsedSnapshot: elapsedSnapshot)
                self.finalSummary   = self.buildSummary()
                self.isSessionEnded = true
            }
            agoraService.leaveChannel()
        }
    }

    private func waitForAllResolveTasks() async {
        let tasks = await MainActor.run { Array(resolveTasks.values) }
        await withTaskGroup(of: Void.self) { group in
            for task in tasks {
                group.addTask {
                    await withTaskGroup(of: Void.self) { inner in
                        inner.addTask { await task.value }
                        inner.addTask { try? await Task.sleep(nanoseconds: 3_000_000_000) }
                        await inner.next()
                        inner.cancelAll()
                    }
                }
            }
        }
    }

    // MARK: - Build Resolved Participants for Summary
    @MainActor
    private func buildResolvedParticipants(elapsedSnapshot: Int) {
        var users: [SoulaceUser] = [currentUser]
        if let myID = currentUser.id, participantJoinTimes[myID] == nil {
            participantJoinTimes[myID] = Date().addingTimeInterval(-Double(elapsedSnapshot))
        }
        for (_, user) in resolvedUsersByAgoraUID {
            users.append(user)
            if let uid = user.id, participantJoinTimes[uid] == nil {
                participantJoinTimes[uid] = Date().addingTimeInterval(-Double(elapsedSnapshot))
            }
        }
        resolvedParticipants = users
        print("✅ resolvedParticipants: \(users.map { $0.fullName })")
    }

    // MARK: - Build Summary
    func buildSummary() -> SessionSummary {
        let totalMin   = max(1, sessionElapsed / 60)
        let sessionEnd = Date()
        var durations: [String: Int] = [:]
        for user in resolvedParticipants {
            guard let uid = user.id else { continue }
            let joinDate  = participantJoinTimes[uid] ?? session.scheduledDate
            let secondsIn = Int(sessionEnd.timeIntervalSince(joinDate))
            durations[uid] = max(1, min(secondsIn / 60, totalMin))
        }
        let longest = resolvedParticipants.max {
            (durations[$0.id ?? ""] ?? 0) < (durations[$1.id ?? ""] ?? 0)
        }
        return SessionSummary(
            session:              session,
            participants:         resolvedParticipants,
            participantDurations: durations,
            longestParticipant:   longest,
            totalMinutes:         totalMin
        )
    }

    // MARK: - Participant Name Resolution
    func resolveParticipantName(agoraUID: UInt) {
        let task = Task {
            if let user = await findUserByAgoraUID(agoraUID) {
                await updateParticipantName(agoraUID: agoraUID, user: user)
                await MainActor.run {
                    self.resolvedUsersByAgoraUID[agoraUID] = user
                }
                if let uid = user.id, participantJoinTimes[uid] == nil {
                    participantJoinTimes[uid] = Date()
                }
            } else {
                await MainActor.run {
                    if let i = self.participants.firstIndex(where: { $0.agoraUID == agoraUID }) {
                        self.participants[i].name     = "Member"
                        self.participants[i].initials = "M"
                    }
                }
            }
            await MainActor.run { self.resolveTasks.removeValue(forKey: agoraUID) }
        }
        resolveTasks[agoraUID] = task
    }

    // ✅ Fix: 5 attempt, delay 0.5s, dual source (group + session)
    private func findUserByAgoraUID(_ agoraUID: UInt) async -> SoulaceUser? {
        for attempt in 0..<5 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(500_000_000 * attempt))
            }

            // Source 1: group memberIDs
            if let group = try? await firestoreService.getGroup(id: session.groupID) {
                for userID in group.memberIDs {
                    if userID == currentUser.id { continue }
                    if CallViewModel.stableUID(from: userID) == agoraUID {
                        if let user = try? await firestoreService.getUser(id: userID) {
                            print("✅ Resolved \(agoraUID) → \(user.fullName) via group (attempt \(attempt+1))")
                            return user
                        }
                    }
                }
            }

            // Source 2: session participantIDs (mulai attempt ke-1)
            if attempt >= 1,
               let sessionID = session.id,
               let fresh = try? await firestoreService.getSession(id: sessionID) {
                for userID in fresh.participantIDs {
                    if userID == currentUser.id { continue }
                    if CallViewModel.stableUID(from: userID) == agoraUID {
                        if let user = try? await firestoreService.getUser(id: userID) {
                            print("✅ Resolved \(agoraUID) → \(user.fullName) via session (attempt \(attempt+1))")
                            return user
                        }
                    }
                }
            }

            print("⚠️ uid \(agoraUID) not resolved, attempt \(attempt+1)/5")
        }
        return nil
    }

    @MainActor
    private func updateParticipantName(agoraUID: UInt, user: SoulaceUser) {
        if let i = participants.firstIndex(where: { $0.agoraUID == agoraUID }) {
            participants[i].name     = user.fullName
            participants[i].initials = user.initials
        }
    }

    // MARK: - Controls
    func toggleMic()    { agoraService.toggleMic() }
    func toggleCamera() { agoraService.toggleCamera() }
    func switchCamera() { agoraService.switchCamera() }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Waiting Room
    private func observeWaitingRoom() {
        guard let sessionID = session.id else { return }
        firestoreService.observeWaitingRoom(sessionID: sessionID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] entries in
                      guard let self else { return }
                      self.waitingEntries = entries
                      if let first = entries.first, self.pendingEntry == nil {
                          self.pendingEntry = first; self.showAdmitSheet = true
                      }
                  })
            .store(in: &cancellables)
    }

    func admitParticipant(_ entry: WaitingEntry) {
        Task {
            try? await firestoreService.updateWaitingStatus(entryID: entry.id ?? "", status: .admitted)
            DispatchQueue.main.async {
                self.waitingEntries.removeAll { $0.id == entry.id }
                self.pendingEntry   = self.waitingEntries.first
                self.showAdmitSheet = self.pendingEntry != nil
            }
        }
    }

    func declineParticipant(_ entry: WaitingEntry) {
        Task {
            try? await firestoreService.updateWaitingStatus(entryID: entry.id ?? "", status: .declined)
            DispatchQueue.main.async {
                self.waitingEntries.removeAll { $0.id == entry.id }
                self.pendingEntry   = self.waitingEntries.first
                self.showAdmitSheet = self.pendingEntry != nil
            }
        }
    }
}
