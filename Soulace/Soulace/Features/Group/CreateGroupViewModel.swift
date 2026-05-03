//
//  CreateGroupViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//


import Foundation
import Contacts
import Combine

// MARK: - CreateGroupViewModel
final class CreateGroupViewModel: ObservableObject {
    @Published var groupName: String            = ""
    @Published var groupDescription: String     = ""
    @Published var searchQuery: String          = ""
    @Published var selectedMembers: [SoulaceUser] = []
    @Published var searchResults: [SoulaceUser]   = []
    @Published var isLoading: Bool              = false
    @Published var showContactsPermission: Bool = false
    @Published var isSyncingContacts: Bool      = false
    @Published var errorMessage: String?        = nil
    @Published var createdGroup: YogaGroup?     = nil
    @Published var isCreated: Bool              = false

    private let firestoreService = FirestoreService.shared
    private let authService      = AuthService.shared
    private var cancellables     = Set<AnyCancellable>()

    var canCreate: Bool { !groupName.isBlank }

    // MARK: - Search Users (Firestore by name)
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

    // MARK: - Request Contacts & Sync
    func requestContactsSync() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if granted {
                    Task { await self.syncContactsWithFirestore(store: store) }
                } else {
                    // User denied — show alert to guide them to Settings
                    self.errorMessage = "Contacts access denied. Please enable it in Settings → Privacy → Contacts."
                }
            }
        }
    }

    // MARK: - Fetch contacts from phonebook → match email ke Firestore users
    @MainActor
    private func syncContactsWithFirestore(store: CNContactStore) async {
        isSyncingContacts = true
        errorMessage      = nil

        // 1. Ambil semua kontak yang punya email
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        var contactEmails: [String] = []
        do {
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            try store.enumerateContacts(with: request) { contact, _ in
                for email in contact.emailAddresses {
                    let emailStr = (email.value as String).lowercased().trimmed
                    if !emailStr.isEmpty { contactEmails.append(emailStr) }
                }
            }
        } catch {
            isSyncingContacts = false
            errorMessage = "Failed to read contacts: \(error.localizedDescription)"
            return
        }

        guard !contactEmails.isEmpty else {
            isSyncingContacts = false
            errorMessage = "No contacts with email found."
            return
        }

        // 2. Match email ke Firestore users
        var matched: [SoulaceUser] = []
        // Batch per 10 (Firestore 'in' limit)
        let batches = stride(from: 0, to: contactEmails.count, by: 10).map {
            Array(contactEmails[$0..<min($0 + 10, contactEmails.count)])
        }

        for batch in batches {
            if let users = try? await firestoreService.getUsersByEmails(batch) {
                let filtered = users.filter { $0.id != authService.currentUser?.id }
                matched.append(contentsOf: filtered)
            }
        }

        isSyncingContacts = false

        if matched.isEmpty {
            errorMessage = "None of your contacts are on Soulace yet."
        } else {
            // Tampilkan ke search results supaya bisa dipilih
            searchResults = matched
            searchQuery   = "" // clear query so user sees the synced results
        }
    }

    // MARK: - Create Group
    @MainActor
    func createGroup() async {
        guard let currentUser = authService.currentUser,
              let userID = currentUser.id else { return }

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
            var created = YogaGroup(
                id:          groupID,
                name:        group.name,
                description: group.description,
                creatorID:   group.creatorID,
                memberIDs:   memberIDs,
                inviteCode:  group.inviteCode
            )
            for memberID in memberIDs {
                try await firestoreService.addUserToGroup(groupID: groupID, userID: memberID)
            }
            NotificationService.shared.subscribeToGroup(groupID)
            createdGroup = created
            isCreated    = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
