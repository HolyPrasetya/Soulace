//
//  CreateGroupViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Contacts
import Combine

import Foundation
import Combine
import Contacts

// MARK: - CreateGroupViewModel
final class CreateGroupViewModel: ObservableObject {
    @Published var groupName: String = ""
    @Published var groupDescription: String = ""
    @Published var searchQuery: String = ""
    @Published var selectedMembers: [SoulaceUser] = []
    @Published var searchResults: [SoulaceUser] = []
    @Published var isLoading: Bool = false
    @Published var showContactsPermission: Bool = false
    @Published var errorMessage: String? = nil
    @Published var createdGroup: YogaGroup? = nil
    @Published var isCreated: Bool = false

    private let firestoreService = FirestoreService.shared
    private let authService      = AuthService.shared

    var canCreate: Bool {
        !groupName.isBlank
    }

    // MARK: - Search Users (Firestore)
    @MainActor
    func searchUsers() async {
        guard !searchQuery.isBlank else {
            searchResults = []
            return
        }
        do {
            let results = try await firestoreService.searchUsers(query: searchQuery)
            // Exclude self
            searchResults = results.filter { $0.id != authService.currentUser?.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleMember(_ user: SoulaceUser) {
        if selectedMembers.contains(where: { $0.id == user.id }) {
            selectedMembers.removeAll { $0.id == user.id }
        } else {
            selectedMembers.append(user)
        }
    }

    func isSelected(_ user: SoulaceUser) -> Bool {
        selectedMembers.contains { $0.id == user.id }
    }

    // MARK: - Request Contacts
    func requestContactsSync() {
        showContactsPermission = true
    }

    // MARK: - Create Group
    @MainActor
    func createGroup() async {
        guard let currentUser = authService.currentUser,
              let userID = currentUser.id else { return }

        isLoading = true
        errorMessage = nil

        var memberIDs = selectedMembers.compactMap { $0.id }
        memberIDs.append(userID) // Include creator

        let group = YogaGroup(
            name: groupName.trimmed,
            description: groupDescription.trimmed,
            creatorID: userID,
            memberIDs: memberIDs
        )

        do {
            let groupID = try await firestoreService.createGroup(group)
            var created = group
            created = YogaGroup(
                id: groupID,
                name: group.name,
                description: group.description,
                creatorID: group.creatorID,
                memberIDs: memberIDs,
                inviteCode: group.inviteCode
            )
            // Add group to each member's profile
            for memberID in memberIDs {
                try await firestoreService.addUserToGroup(groupID: groupID, userID: memberID)
            }
            // Subscribe to FCM topic
            NotificationService.shared.subscribeToGroup(groupID)
            createdGroup = created
            isCreated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
