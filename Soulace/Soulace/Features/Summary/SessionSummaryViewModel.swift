//
//  SessionSummaryViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Combine

// MARK: - SessionSummaryViewModel
final class SessionSummaryViewModel: ObservableObject {
    @Published var participantDetails: [SoulaceUser] = []
    @Published var isLoading: Bool = false

    let summary: SessionSummary

    private let firestoreService = FirestoreService.shared
    private var cancellables     = Set<AnyCancellable>()

    init(summary: SessionSummary) {
        self.summary = summary
        fetchParticipantDetails()
    }

    // MARK: - Fetch participant names from Firestore
    private func fetchParticipantDetails() {
        let ids = summary.session.participantIDs
        guard !ids.isEmpty else { return }
        isLoading = true

        Task {
            var users: [SoulaceUser] = []
            for id in ids {
                if let user = try? await firestoreService.getUser(id: id) {
                    users.append(user)
                }
            }
            await MainActor.run {
                self.participantDetails = users
                self.isLoading = false
            }
        }
    }

    // MARK: - Computed helpers
    var totalMinutes: Int       { summary.totalMinutes }
    var participantCount: Int   { summary.session.participantIDs.count }
    var groupName: String       { summary.session.groupName }
    var durationMinutes: Int    { summary.session.durationMinutes }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy · h:mm a"
        return f.string(from: summary.session.scheduledDate)
    }

    var motivationalQuote: String {
        let quotes = [
            "The only bad workout is the one that didn't happen.",
            "Yoga is the journey of the self, through the self, to the self.",
            "Your body can do it. It's your mind you have to convince.",
            "The pose begins when you want to leave it.",
            "Breathe. You've got this.",
            "Consistency is the key to transformation."
        ]
        return quotes.randomElement() ?? quotes[0]
    }

    // Longest participant name
    var longestParticipantName: String {
        guard let longest = summary.longestParticipant else { return "—" }
        return longest.fullName.components(separatedBy: " ").first ?? "—"
    }

    var longestParticipantMinutes: Int {
        guard let longest = summary.longestParticipant,
              let id      = longest.id else { return 0 }
        return summary.participantDurations[id] ?? 0
    }

    // Sorted durations for bar chart
    var sortedDurations: [(name: String, minutes: Int)] {
        summary.participantDurations
            .compactMap { userID, minutes -> (String, Int)? in
                let name = participantDetails.first { $0.id == userID }?.fullName
                    ?? "Participant"
                return (name.components(separatedBy: " ").first ?? name, minutes)
            }
            .sorted { $0.1 > $1.1 }
    }
}
