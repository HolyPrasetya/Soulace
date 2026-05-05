//
//  HomeViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    @Published var groups: [YogaGroup]              = []
    @Published var upcomingSessions: [YogaSession]  = []
    @Published var isLoading: Bool                  = false
    @Published var errorMessage: String?            = nil
    @Published var showCreateGroup: Bool            = false
    @Published var showJoinSession: Bool            = false
    // ✅ Invitations
    @Published var pendingInvitations: [GroupInvitation] = []
    @Published var showInvitations: Bool            = false

    private let firestoreService     = FirestoreService.shared
    private let authService          = AuthService.shared
    private let invitationService    = GroupInvitationService.shared
    private var cancellables         = Set<AnyCancellable>()
    private var sessionCancellables  = Set<AnyCancellable>()

    var currentUser: SoulaceUser? { authService.currentUser }

    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    init() {
        fetchGroups()
        observeInvitations()
    }

    func fetchGroups() {
        guard let userID = authService.currentUser?.id else { return }
        isLoading = true
        firestoreService.getUserGroups(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] groups in
                    guard let self else { return }
                    self.groups    = groups
                    self.isLoading = false
                    self.subscribeToAllSessions(for: groups)
                }
            )
            .store(in: &cancellables)
    }

    private func subscribeToAllSessions(for groups: [YogaGroup]) {
        sessionCancellables.removeAll()
        upcomingSessions = []
        for group in groups {
            guard let groupID = group.id else { continue }
            firestoreService.getUpcomingSessions(groupID: groupID)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in },
                      receiveValue: { [weak self] sessions in
                          guard let self else { return }
                          self.upcomingSessions.removeAll { $0.groupID == groupID }
                          self.upcomingSessions.append(contentsOf: sessions)
                          self.upcomingSessions.sort { $0.scheduledDate < $1.scheduledDate }
                      })
                .store(in: &sessionCancellables)
        }
    }

    // ✅ Listen pending invitations realtime
    private func observeInvitations() {
        guard let userID = authService.currentUser?.id else { return }
        invitationService.observeInvitations(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] invites in
                      self?.pendingInvitations = invites
                  })
            .store(in: &cancellables)
    }

    func signOut() { authService.signOut() }
}
