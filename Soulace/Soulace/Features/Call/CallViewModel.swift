//
//  CallViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
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
    @Published var sessionElapsed: Int              = 0       // seconds
    @Published var sessionRemaining: Int            = 0       // seconds
    @Published var showVideoPlayer: Bool            = false
    @Published var showAdmitSheet: Bool             = false
    @Published var pendingEntry: WaitingEntry?      = nil
    @Published var errorMessage: String?            = nil
    @Published var isSessionEnded: Bool             = false
    @Published var tooManyParticipants: Bool        = false

    // MARK: Session info
    let session: YogaSession
    let currentUser: SoulaceUser
    var selectedVideo: VideoContent?

    // MARK: Private
    private let agoraService    = AgoraService.shared
    private let firestoreService = FirestoreService.shared
    private var cancellables    = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var joinTimes: [String: Date] = [:]

    // MARK: Computed
    var isHost: Bool { session.hostID == currentUser.id }
    var durationSeconds: Int { session.durationMinutes * 60 }

    var elapsedFormatted: String { formatTime(sessionElapsed) }
    var remainingFormatted: String { formatTime(sessionRemaining) }

    var participantCount: Int { participants.count + 1 } // +1 for local user

    init(session: YogaSession, currentUser: SoulaceUser, video: VideoContent? = nil) {
        self.session      = session
        self.currentUser  = currentUser
        self.selectedVideo = video
        self.sessionRemaining = session.durationMinutes * 60
        observeAgora()
    }

    // MARK: - Observe Agora Service
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
                if joined { self?.startSessionTimer() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Join Call
    func joinCall() {
        guard let userID = currentUser.id else { return }
        let uid = UInt(abs(userID.hashValue) % 100000)
        agoraService.joinChannel(session.agoraChannelName, userID: uid)
        joinTimes[userID] = Date()

        // Update Firestore
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

        // Observe waiting room if host
        if isHost { observeWaitingRoom() }
    }

    // MARK: - Leave / End Call
    func leaveCall() {
        sessionTimer?.invalidate()
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

    // MARK: - Toggle Controls
    func toggleMic()    { agoraService.toggleMic() }
    func toggleCamera() { agoraService.toggleCamera() }
    func switchCamera() { agoraService.switchCamera() }

    // MARK: - Session Timer
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.sessionElapsed   += 1
                self.sessionRemaining  = max(0, self.durationSeconds - self.sessionElapsed)

                if self.sessionRemaining == 0 {
                    self.sessionTimer?.invalidate()
                    self.leaveCall()
                }
            }
        }
    }

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
            try? await firestoreService.updateWaitingStatus(
                entryID: entry.id ?? "",
                status: .admitted
            )
            DispatchQueue.main.async {
                self.waitingEntries.removeAll { $0.id == entry.id }
                self.pendingEntry   = self.waitingEntries.first
                self.showAdmitSheet = self.pendingEntry != nil
            }
        }
    }

    func declineParticipant(_ entry: WaitingEntry) {
        Task {
            try? await firestoreService.updateWaitingStatus(
                entryID: entry.id ?? "",
                status: .declined
            )
            DispatchQueue.main.async {
                self.waitingEntries.removeAll { $0.id == entry.id }
                self.pendingEntry   = self.waitingEntries.first
                self.showAdmitSheet = self.pendingEntry != nil
            }
        }
    }

    // MARK: - Session Summary
    func buildSummary() -> SessionSummary {
        SessionSummary(
            session: session,
            participants: [],        // fetch from Firestore in summary view
            participantDurations: [:],
            longestParticipant: nil,
            totalMinutes: sessionElapsed / 60
        )
    }
}
