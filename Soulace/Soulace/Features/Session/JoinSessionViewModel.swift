//
//  JoinSessionViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Combine

// MARK: - JoinSessionViewModel
final class JoinSessionViewModel: ObservableObject {
    @Published var codeOrLink: String        = ""
    @Published var isLoading: Bool           = false
    @Published var errorMessage: String?     = nil
    @Published var foundGroup: YogaGroup?    = nil
    @Published var navigateToCall: Bool      = false
    @Published var recentGroups: [YogaGroup] = []

    private let firestoreService = FirestoreService.shared
    private let authService      = AuthService.shared
    private var cancellables     = Set<AnyCancellable>()

    init() { loadRecentGroups() }

    // MARK: - Load Recent Groups
    private func loadRecentGroups() {
        guard let userID = authService.currentUser?.id else { return }

        firestoreService.getUserGroups(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] groups in
                    self?.recentGroups = Array(groups.prefix(3))
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Join with Code or Link
    @MainActor
    func joinWithCode() async {
        // Extract code from link if user pasted a full link
        let raw  = codeOrLink.trimmed
        let code = extractCode(from: raw).uppercased()
        guard !code.isBlank else { return }

        isLoading    = true
        errorMessage = nil

        do {
            if let group = try await firestoreService.getGroupByInviteCode(code) {
                foundGroup = group

                if let groupID = group.id,
                   let userID  = authService.currentUser?.id {
                    try await firestoreService.addUserToGroup(groupID: groupID, userID: userID)
                    NotificationService.shared.subscribeToGroup(groupID)
                }
                navigateToCall = true

            } else {
                errorMessage = "Group not found. Double-check the code and try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Validation
    var canJoin: Bool { !codeOrLink.trimmed.isBlank }

    // MARK: - Extract code from deep link if pasted
    /// Supports plain codes like "YOGA-1234" or links like "soulace://join/YOGA-1234"
    private func extractCode(from input: String) -> String {
        if input.contains("://") {
            return input.components(separatedBy: "/").last ?? input
        }
        return input
    }
}
