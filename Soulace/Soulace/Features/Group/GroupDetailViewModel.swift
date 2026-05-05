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
    @Published var sessions: [YogaSession]   = []
    @Published var isLoading: Bool           = false
    @Published var errorMessage: String?     = nil
    @Published var showCreateSession: Bool   = false
    @Published var showInviteMember: Bool    = false
    @Published var showInviteCopied: Bool    = false
    @Published var showDeleteConfirm: Bool   = false  // delete group alert
    @Published var showLeaveConfirm: Bool    = false  // leave group alert
    @Published var isDeleting: Bool          = false
    @Published var groupDeleted: Bool        = false  // trigger dismiss after delete

    let group: YogaGroup

    private let firestoreService = FirestoreService.shared
    private let authService      = AuthService.shared
    private var cancellables     = Set<AnyCancellable>()

    var currentUserID: String? { authService.currentUser?.id }
    var isCreator: Bool { group.creatorID == currentUserID }

    init(group: YogaGroup) {
        self.group = group
        fetchSessions()
    }

    // MARK: - Fetch Sessions
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

    // MARK: - Delete Group (creator only)
    @MainActor
    func deleteGroup() async {
        guard let groupID = group.id, isCreator else { return }
        isDeleting = true
        errorMessage = nil

        do {
            try await firestoreService.deleteGroup(
                groupID:   groupID,
                memberIDs: group.memberIDs
            )
            NotificationService.shared.unsubscribeFromGroup(groupID)
            groupDeleted = true
            print("✅ Group deleted: \(group.name)")
        } catch {
            errorMessage = "Failed to delete group: \(error.localizedDescription)"
            print("❌ Delete group error: \(error)")
        }
        isDeleting = false
    }

    // MARK: - Leave Group (non-creator)
    @MainActor
    func leaveGroup() async {
        guard let groupID = group.id,
              let userID  = currentUserID,
              !isCreator else { return }
        isDeleting = true
        errorMessage = nil

        do {
            try await firestoreService.leaveGroup(groupID: groupID, userID: userID)
            NotificationService.shared.unsubscribeFromGroup(groupID)
            groupDeleted = true
            print("✅ Left group: \(group.name)")
        } catch {
            errorMessage = "Failed to leave group: \(error.localizedDescription)"
            print("❌ Leave group error: \(error)")
        }
        isDeleting = false
    }

    // MARK: - Helper
    var memberLabel: String {
        "\(group.memberCount) \(group.memberCount == 1 ? "member" : "members")"
    }

    // Label for action button based on role
    var groupActionLabel: String { isCreator ? "Delete Group" : "Leave Group" }
    var groupActionIcon:  String { isCreator ? "trash.fill"   : "rectangle.portrait.and.arrow.right" }
}
