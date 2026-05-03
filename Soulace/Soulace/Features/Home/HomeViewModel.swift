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
    @Published var groups: [YogaGroup]           = []
    @Published var upcomingSessions: [YogaSession] = []
    @Published var isLoading: Bool               = false
    @Published var errorMessage: String?         = nil
    @Published var showCreateGroup: Bool         = false
    @Published var showJoinSession: Bool         = false

    private let firestoreService = FirestoreService.shared
    private let authService      = AuthService.shared
    private var cancellables     = Set<AnyCancellable>()
    // Simpan session cancellables terpisah supaya bisa di-reset saat groups berubah
    private var sessionCancellables = Set<AnyCancellable>()

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

    // MARK: - Fetch Groups (realtime listener)
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
                    // Reset dan re-subscribe session listeners setiap kali groups berubah
                    self.subscribeToAllSessions(for: groups)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Subscribe realtime sessions untuk semua groups
    private func subscribeToAllSessions(for groups: [YogaGroup]) {
        // Cancel semua session listener lama
        sessionCancellables.removeAll()
        upcomingSessions = []

        for group in groups {
            guard let groupID = group.id else { continue }

            firestoreService.getUpcomingSessions(groupID: groupID)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { [weak self] sessions in
                        guard let self else { return }
                        // Hapus session lama dari group ini, replace dengan yang baru
                        self.upcomingSessions.removeAll { $0.groupID == groupID }
                        self.upcomingSessions.append(contentsOf: sessions)
                        // Sort by date
                        self.upcomingSessions.sort { $0.scheduledDate < $1.scheduledDate }
                    }
                )
                .store(in: &sessionCancellables)
        }
    }

    func signOut() {
        authService.signOut()
    }
}
