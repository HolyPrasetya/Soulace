//
//  GroupDetailViewModel.swift
//  Soulace
//
//  The active GroupDetailViewModel implementation lives in GroupDetailView.swift.
//

import Foundation
import Combine
import UIKit

// MARK: - GroupDetailViewModel
final class GroupDetailViewModel: ObservableObject {
    @Published var sessions: [YogaSession]  = []
    @Published var isLoading: Bool          = false
    @Published var errorMessage: String?    = nil
    @Published var showCreateSession: Bool  = false
    @Published var showInviteCopied: Bool   = false

    let group: YogaGroup

    private let firestoreService = FirestoreService.shared
    private var cancellables     = Set<AnyCancellable>()

    init(group: YogaGroup) {
        self.group = group
        fetchSessions()
    }

    // MARK: - Fetch Upcoming Sessions
    func fetchSessions() {
        guard let groupID = group.id else { return }
        isLoading = true

        firestoreService.getUpcomingSessions(groupID: groupID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] sessions in
                    self?.sessions = sessions
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Copy Invite Code
    func copyInviteCode() {
        UIPasteboard.general.string = group.inviteCode
        showInviteCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showInviteCopied = false
        }
    }

    // MARK: - Member count label
    var memberLabel: String {
        "\(group.memberCount) \(group.memberCount == 1 ? "member" : "members")"
    }
}
