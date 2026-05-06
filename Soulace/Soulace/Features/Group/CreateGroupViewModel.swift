//
//  CreateGroupViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Combine
import Contacts

final class CreateGroupViewModel: ObservableObject {
    @Published var groupName:              String        = ""
    @Published var groupDescription:       String        = ""
    @Published var searchQuery:            String        = ""
    @Published var selectedMembers:        [SoulaceUser] = []
    @Published var searchResults:          [SoulaceUser] = []
    @Published var isLoading:              Bool          = false
    @Published var isSyncingContacts:      Bool          = false
    @Published var showContactsPermission: Bool          = false
    @Published var contactSyncMessage:     String?       = nil
    @Published var errorMessage:           String?       = nil
    @Published var createdGroup:           YogaGroup?    = nil
    @Published var isCreated:              Bool          = false

    private let firestoreService  = FirestoreService.shared
    private let authService       = AuthService.shared
    private let invitationService = GroupInvitationService.shared
    private var cancellables      = Set<AnyCancellable>()

    var canCreate: Bool { !groupName.isBlank }

    // MARK: - Search Firestore Users
    @MainActor
    func searchUsers() async {
        guard !searchQuery.isBlank else { searchResults = []; return }
        do {
            let results = try await firestoreService.searchUsers(query: searchQuery)
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

    // MARK: - Contacts Sync
    func requestContactsSync() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted { Task { await self.syncContactsWithFirestore(store: store) } }
                else { self.contactSyncMessage = "Contacts access denied. Enable in Settings → Soulace → Contacts." }
            }
        }
    }

    @MainActor
    private func syncContactsWithFirestore(store: CNContactStore) async {
        isSyncingContacts  = true
        contactSyncMessage = nil
        do {
            let keysToFetch = [CNContactEmailAddressesKey] as [CNKeyDescriptor]
            var emails: [String] = []
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            try store.enumerateContacts(with: request) { contact, _ in
                emails.append(contentsOf: contact.emailAddresses.map { $0.value as String })
            }
            guard !emails.isEmpty else {
                contactSyncMessage = "No email contacts found on this device."
                isSyncingContacts  = false
                return
            }
            var foundUsers: [SoulaceUser] = []
            for chunk in stride(from: 0, to: emails.count, by: 10).map({ Array(emails[$0..<min($0+10, emails.count)]) }) {
                let users = try await firestoreService.getUsersByEmails(chunk)
                foundUsers.append(contentsOf: users)
            }
            let selfID   = authService.currentUser?.id
            let filtered = foundUsers.filter { user in
                user.id != selfID && !selectedMembers.contains { member in
                    member.id == user.id
                }
            }
            if filtered.isEmpty { contactSyncMessage = "None of your contacts are on Soulace yet." }
            else { searchResults = filtered; contactSyncMessage = "Found \(filtered.count) friend(s) on Soulace!" }
        } catch {
            contactSyncMessage = "Could not read contacts: \(error.localizedDescription)"
        }
        isSyncingContacts = false
    }

    // MARK: - Create Group
    @MainActor
    func createGroup() async {
        guard let currentUser = authService.currentUser,
              let userID      = currentUser.id else { return }

        isLoading    = true
        errorMessage = nil

        // Hanya creator yang langsung masuk grup
        let group = YogaGroup(
            name:        groupName.trimmed,
            description: groupDescription.trimmed,
            creatorID:   userID,
            memberIDs:   [userID]
        )

        do {
            let groupID = try await firestoreService.createGroup(group)

            // Tambah creator ke groupIDs miliknya
            try await firestoreService.addUserToGroup(groupID: groupID, userID: userID)

            NotificationService.shared.subscribeToGroup(groupID)

            // Buat YogaGroup lengkap dengan ID untuk kirim invitation
            let createdGroupObj = YogaGroup(
                id:          groupID,
                name:        group.name,
                description: group.description,
                creatorID:   userID,
                memberIDs:   [userID],
                inviteCode:  group.inviteCode
            )

            // Kirim invitation ke semua selected members
            for member in selectedMembers {
                guard let toID = member.id else { continue }
                try? await invitationService.sendInvitation(
                    group:    createdGroupObj,
                    fromUser: currentUser,
                    toUserID: toID
                )
            }

            createdGroup = createdGroupObj
            isCreated    = true

            let inviteCount = selectedMembers.count
            print("✅ Group '\(group.name)' created. Invitations sent to \(inviteCount) member(s).")

        } catch {
            errorMessage = error.localizedDescription
            print("❌ Create group error: \(error)")
        }

        isLoading = false
    }
}
