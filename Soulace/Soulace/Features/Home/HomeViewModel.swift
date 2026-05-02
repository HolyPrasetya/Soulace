//
//  HomeViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Combine

// MARK: - HomeViewModel
final class HomeViewModel: ObservableObject {
    @Published var groups: [YogaGroup] = []
    @Published var upcomingSessions: [YogaSession] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showCreateGroup: Bool = false
    @Published var showJoinSession: Bool = false

    private let firestoreService = FirestoreService.shared
    private let authService      = AuthService.shared
    private var cancellables     = Set<AnyCancellable>()

    var currentUser: SoulaceUser? { authService.currentUser }

    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    init() { fetchGroups() }

    // MARK: - Fetch Groups
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
                    self?.groups = groups
                    self?.isLoading = false
                    self?.fetchUpcomingSessions(for: groups)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Fetch Sessions across all groups
    private func fetchUpcomingSessions(for groups: [YogaGroup]) {
        upcomingSessions = []
        for group in groups {
            guard let groupID = group.id else { continue }
            firestoreService.getUpcomingSessions(groupID: groupID)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { [weak self] sessions in
                        guard let self else { return }
                        let existing = self.upcomingSessions.map { $0.id }
                        let newSessions = sessions.filter { !existing.contains($0.id) }
                        self.upcomingSessions.append(contentsOf: newSessions)
                        self.upcomingSessions.sort { $0.scheduledDate < $1.scheduledDate }
                    }
                )
                .store(in: &cancellables)
        }
    }

    func signOut() {
        authService.signOut()
    }
}
