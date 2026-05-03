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

// MARK: - CallViewModel
final class CallViewModel: ObservableObject {

    // MARK: Published State
    @Published var participants: [CallParticipant]  = []
    @Published var waitingEntries: [WaitingEntry]   = []
    @Published var isJoined: Bool                   = false
    @Published var isMuted: Bool                    = false
    @Published var isCameraOff: Bool                = false
    @Published var sessionElapsed: Int              = 0
    @Published var sessionRemaining: Int            = 0
    @Published var showVideoPlayer: Bool            = false
    @Published var showParticipantsPanel: Bool      = false   // ← Bug 3: panel participants
    @Published var showAdmitSheet: Bool             = false
    @Published var pendingEntry: WaitingEntry?      = nil
    @Published var errorMessage: String?            = nil
    @Published var isSessionEnded: Bool             = false
    @Published var isTimerRunning: Bool             = false   // ← Bug 4: timer state
    @Published var navigateHome: Bool               = false   // ← Bug 5: back to home

    // MARK: Session info
    let session: YogaSession
    let currentUser: SoulaceUser
    var selectedVideo: VideoContent?

    // MARK: Private
    private let agoraService     = AgoraService.shared
    private let firestoreService = FirestoreService.shared
    private var cancellables     = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var joinTimes: [String: Date] = [:]

    // MARK: Computed
    var isHost: Bool        { session.hostID == currentUser.id }
    var durationSeconds: Int { session.durationMinutes * 60 }
    var elapsedFormatted: String   { formatTime(sessionElapsed) }
    var remainingFormatted: String { formatTime(sessionRemaining) }
    var participantCount: Int      { participants.count + 1 }

    init(session: YogaSession, currentUser: SoulaceUser, video: VideoContent? = nil) {
        self.session       = session
        self.currentUser   = currentUser
        self.selectedVideo = video
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

        // Bug 4: Tidak hanya rely pada isJoined — timer bisa manual start juga
        agoraService.$isJoined
            .receive(on: DispatchQueue.main)
            .sink { [weak self] joined in
                self?.isJoined = joined
                // Auto-start timer ketika berhasil join Agora channel
                if joined { self?.startTimer() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Join Call
    func joinCall() {
        guard let userID = currentUser.id else { return }
        let uid = UInt(abs(userID.hashValue) % 100000)
        agoraService.joinChannel(session.agoraChannelName, userID: uid)
        joinTimes[userID] = Date()

        Task {
            try? await firestoreService.addParticipantToSession(
                sessionID: session.id ?? "",
                userID: userID
            )
            try? await firestoreService.updateSessionStatus(
                id: session.id ?? "",
                status: .live
            )
        }

        if isHost { observeWaitingRoom() }
    }

    // MARK: - Bug 4: Manual start timer (jika Agora lambat join atau testing tanpa Agora)
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

    // MARK: - Bug 5: Back = go home WITHOUT ending call
    func goHome() {
        // Dismiss view saja, tidak leave channel
        DispatchQueue.main.async { self.navigateHome = true }
    }

    // MARK: - End Call (hanya dari tombol End merah)
    func leaveCall() {
        pauseTimer()
        agoraService.leaveChannel()
        Task {
            if isHost {
                try? await firestoreService.updateSessionStatus(
                    id: session.id ?? "",
                    status: .completed
                )
            }
        }
        DispatchQueue.main.async { self.isSessionEnded = true }
    }

    // MARK: - Session ended by timer
    private func endSession() {
        agoraService.leaveChannel()
        Task {
            if isHost {
                try? await firestoreService.updateSessionStatus(
                    id: session.id ?? "",
                    status: .completed
                )
            }
        }
        DispatchQueue.main.async { self.isSessionEnded = true }
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

    // MARK: - Waiting Room (host only)
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
            session: session,
            participants: [],
            participantDurations: [:],
            longestParticipant: nil,
            totalMinutes: sessionElapsed / 60
        )
    }
}
