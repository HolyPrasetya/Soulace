//
//  CallViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//


import Foundation
import Combine
import AVFoundation

final class CallViewModel: ObservableObject {

    @Published var participants: [CallParticipant]  = []
    @Published var waitingEntries: [WaitingEntry]   = []
    @Published var isJoined: Bool                   = false
    @Published var isMuted: Bool                    = false
    @Published var isCameraOff: Bool                = false
    @Published var sessionElapsed: Int              = 0
    @Published var sessionRemaining: Int            = 0
    @Published var showVideoPlayer: Bool            = false
    @Published var isVideoPlaying: Bool             = true
    @Published var showParticipantsPanel: Bool      = false
    @Published var showAdmitSheet: Bool             = false
    @Published var pendingEntry: WaitingEntry?      = nil
    @Published var errorMessage: String?            = nil
    @Published var isSessionEnded: Bool             = false
    @Published var isTimerRunning: Bool             = false
    @Published var navigateHome: Bool               = false

    let session: YogaSession
    let currentUser: SoulaceUser
    var selectedVideo: VideoContent?

    private let agoraService     = AgoraService.shared
    private let firestoreService = FirestoreService.shared
    private var cancellables     = Set<AnyCancellable>()
    private var sessionTimer: Timer?

    var isHost: Bool         { session.hostID == currentUser.id }
    var durationSeconds: Int { session.durationMinutes * 60 }
    var elapsedFormatted: String   { formatTime(sessionElapsed) }
    var remainingFormatted: String { formatTime(sessionRemaining) }
    var participantCount: Int      { participants.count + 1 }

    init(session: YogaSession, currentUser: SoulaceUser, video: VideoContent? = nil) {
        self.session          = session
        self.currentUser      = currentUser
        self.selectedVideo    = video
        self.sessionRemaining = session.durationMinutes * 60
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
        let uid = stableAgoraUID(for: userID)

        agoraService.onRemoteUserJoined = { [weak self] agoraUID in
            self?.resolveParticipantName(agoraUID: agoraUID)
        }

        agoraService.joinChannel(session.agoraChannelName, userID: uid)

        Task {
            try? await firestoreService.addParticipantToSession(
                sessionID: session.id ?? "", userID: userID
            )
            try? await firestoreService.updateSessionStatus(
                id: session.id ?? "", status: .live
            )
        }

        if isHost { observeWaitingRoom() }
    }

    // MARK: - Resolve participant name
    // ✅ Strategy: scan semua member group dan cocokkan deterministic Agora UID
    // Tidak bergantung pada participantIDs (timing issue) atau urutan join
    private func resolveParticipantName(agoraUID: UInt) {
        Task {
            // Coba langsung dari group members — paling reliable
            if let user = await findUserByAgoraUID(agoraUID, retries: 3) {
                updateParticipantName(agoraUID: agoraUID, user: user)
            } else {
                // Gagal resolve — set nama yang lebih baik dari "Loading..."
                await MainActor.run {
                    if let i = self.participants.firstIndex(where: { $0.agoraUID == agoraUID }) {
                        self.participants[i].name     = "Member"
                        self.participants[i].initials = "M"
                    }
                }
            }
        }
    }

    // ✅ Scan semua member group, cocokkan UID yang dihitung secara deterministik
    // Retry dengan delay untuk handle timing issue Firestore
    private func findUserByAgoraUID(_ agoraUID: UInt, retries: Int) async -> SoulaceUser? {
        for attempt in 0..<retries {
            // Delay makin lama tiap retry: 0s, 1s, 2s
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }

            // Fetch group untuk dapat member list terbaru
            guard let group = try? await firestoreService.getGroup(id: session.groupID) else {
                continue
            }

            // Scan semua member — skip diri sendiri
            for userID in group.memberIDs {
                if userID == currentUser.id { continue }

                let expectedUID = stableAgoraUID(for: userID)
                if expectedUID == agoraUID {
                    if let user = try? await firestoreService.getUser(id: userID) {
                        print("✅ Resolved uid \(agoraUID) → \(user.fullName) (attempt \(attempt + 1))")
                        return user
                    }
                }
            }

            print("⚠️ Could not resolve uid \(agoraUID) on attempt \(attempt + 1), retrying...")
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

    private func stableAgoraUID(for userID: String) -> UInt {
        var hash: UInt64 = 5381

        for byte in userID.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }

        return UInt(hash % 99_999) + 1
    }

    // MARK: - Timer
    func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        sessionTimer   = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.sessionElapsed   += 1
                self.sessionRemaining  = max(0, self.durationSeconds - self.sessionElapsed)
                if self.sessionRemaining == 0 {
                    self.sessionTimer?.invalidate()
                    self.isTimerRunning = false
                    self.endSession()
                }
            }
        }
    }

    func pauseTimer() {
        sessionTimer?.invalidate()
        sessionTimer   = nil
        isTimerRunning = false
    }

    func toggleTimer() {
        if isTimerRunning { pauseTimer() } else { startTimer() }
    }

    func goHome() {
        DispatchQueue.main.async { self.navigateHome = true }
    }

    func leaveCall() {
        pauseTimer()
        agoraService.leaveChannel()
        Task {
            if isHost {
                try? await firestoreService.updateSessionStatus(
                    id: session.id ?? "", status: .completed
                )
            }
        }
        DispatchQueue.main.async { self.isSessionEnded = true }
    }

    private func endSession() {
        agoraService.leaveChannel()
        Task {
            if isHost {
                try? await firestoreService.updateSessionStatus(
                    id: session.id ?? "", status: .completed
                )
            }
        }
        DispatchQueue.main.async { self.isSessionEnded = true }
    }

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

    private func observeWaitingRoom() {
        guard let sessionID = session.id else { return }
        firestoreService.observeWaitingRoom(sessionID: sessionID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] entries in
                      guard let self else { return }
                      self.waitingEntries = entries
                      if let first = entries.first, self.pendingEntry == nil {
                          self.pendingEntry   = first
                          self.showAdmitSheet = true
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

    func buildSummary() -> SessionSummary {
        SessionSummary(
            session: session, participants: [],
            participantDurations: [:], longestParticipant: nil,
            totalMinutes: sessionElapsed / 60
        )
    }
}
