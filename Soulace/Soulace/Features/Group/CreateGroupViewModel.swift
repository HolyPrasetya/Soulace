//
//  CreateGroupViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Combine
import Contacts

// MARK: - CreateGroupViewModel
final class CreateGroupViewModel: ObservableObject {
    @Published var groupName:             String         = ""
    @Published var groupDescription:      String         = ""
    @Published var searchQuery:           String         = ""
    @Published var selectedMembers:       [SoulaceUser]  = []
    @Published var searchResults:         [SoulaceUser]  = []
    @Published var isLoading:             Bool           = false
    @Published var isSyncingContacts:     Bool           = false  // Bug 2 fix
    @Published var showContactsPermission: Bool          = false
    @Published var contactSyncMessage:    String?        = nil    // Bug 2 fix
    @Published var errorMessage:          String?        = nil
    @Published var createdGroup:          YogaGroup?     = nil
    @Published var isCreated:             Bool           = false

    private let firestoreService = FirestoreService.shared
    private let authService      = AuthService.shared
    private var cancellables     = Set<AnyCancellable>()

    var canCreate: Bool { !groupName.isBlank }

    // MARK: - Search Firestore Users
    @MainActor
    func searchUsers() async {
        guard !searchQuery.isBlank else {
            searchResults = []
            return
        }
        do {
            let results = try await firestoreService.searchUsers(query: searchQuery)
            searchResults = results.filter { $0.id != authService.currentUser?.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Toggle member selection
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

    // MARK: ── Bug 2 Fix: Contacts Sync Actually Works ──
    func requestContactsSync() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    Task { await self.syncContactsWithFirestore(store: store) }
                } else {
                    self.contactSyncMessage = "Contacts access denied. Enable in Settings → Soulace → Contacts."
                }
            }
        }
    }

    @MainActor
    private func syncContactsWithFirestore(store: CNContactStore) async {
        isSyncingContacts = true
        contactSyncMessage = nil

        do {
            // 1. Fetch all contact emails from device
            let keysToFetch = [CNContactEmailAddressesKey] as [CNKeyDescriptor]
            var emails: [String] = []

            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            try store.enumerateContacts(with: request) { contact, _ in
                let contactEmails = contact.emailAddresses.map { $0.value as String }
                emails.append(contentsOf: contactEmails)
            }

            guard !emails.isEmpty else {
                contactSyncMessage = "No email contacts found on this device."
                isSyncingContacts = false
                return
            }

            print("📱 Contacts: found \(emails.count) emails, querying Firestore...")

            // 2. Query Firestore for users with those emails (in batches of 10 — Firestore limit)
            var foundUsers: [SoulaceUser] = []
            let emailChunks = stride(from: 0, to: emails.count, by: 10).map {
                Array(emails[$0..<min($0 + 10, emails.count)])
            }

            for chunk in emailChunks {
                let users = try await firestoreService.getUsersByEmails(chunk)
                foundUsers.append(contentsOf: users)
            }

            // 3. Exclude self and already-selected members
            let selfID = authService.currentUser?.id
            let filtered = foundUsers.filter { user in
                user.id != selfID &&
                !selectedMembers.contains(where: { $0.id == user.id })
            }

            if filtered.isEmpty {
                contactSyncMessage = "None of your contacts are on Soulace yet."
            } else {
                // Show found users in search results
                searchResults = filtered
                contactSyncMessage = "Found \(filtered.count) friend(s) on Soulace!"
            }

            print("📱 Contacts sync: found \(filtered.count) Soulace users")

        } catch {
            contactSyncMessage = "Could not read contacts: \(error.localizedDescription)"
            print("📱 Contacts sync error: \(error)")
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

        var memberIDs = selectedMembers.compactMap { $0.id }
        memberIDs.append(userID)

        let group = YogaGroup(
            name:        groupName.trimmed,
            description: groupDescription.trimmed,
            creatorID:   userID,
            memberIDs:   memberIDs
        )

        do {
            let groupID = try await firestoreService.createGroup(group)

            // Add group to all members
            for memberID in memberIDs {
                try await firestoreService.addUserToGroup(groupID: groupID, userID: memberID)
            }

            NotificationService.shared.subscribeToGroup(groupID)

            createdGroup = YogaGroup(
                id:          groupID,
                name:        group.name,
                description: group.description,
                creatorID:   userID,
                memberIDs:   memberIDs,
                inviteCode:  group.inviteCode
            )
            isCreated = true
            print("✅ Group created: \(group.name) with \(memberIDs.count) members")

        } catch {
            errorMessage = error.localizedDescription
            print("❌ Create group error: \(error)")
        }

        isLoading = false
    }
}
