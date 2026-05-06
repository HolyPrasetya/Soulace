//
//  SessionSummaryViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Combine

final class SessionSummaryViewModel: ObservableObject {

    // MARK: - Published
    @Published var participantMap: [String: SoulaceUser] = [:]
    @Published var isResolvingNames: Bool = true

    let summary: SessionSummary

    private let firestoreService = FirestoreService.shared

    init(summary: SessionSummary) {
        self.summary = summary
        resolveParticipants()
    }

    // MARK: - 🔥 FIX: Parallel + Stable Fetch
    private func resolveParticipants() {
        let ids = Array(summary.participantDurations.keys)

        guard !ids.isEmpty else {
            isResolvingNames = false
            return
        }

        Task {
            var result: [String: SoulaceUser] = [:]

            await withTaskGroup(of: (String, SoulaceUser?).self) { group in
                for id in ids {
                    group.addTask {
                        let user = try? await self.firestoreService.getUser(id: id)
                        return (id, user)
                    }
                }

                for await (id, user) in group {
                    if let user {
                        result[id] = user
                    }
                }
            }

            await MainActor.run {
                self.participantMap = result
                self.isResolvingNames = false
            }
        }
    }

    // MARK: - Basic Info
    var totalMinutes: Int { summary.totalMinutes }

    var participantCount: Int {
        summary.participantDurations.count
    }

    var groupName: String {
        summary.session.groupName
    }

    var durationMinutes: Int {
        summary.session.durationMinutes
    }

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

    // MARK: - 🧠 FIX: Longest Participant (CONSISTENT)
    var longestParticipantID: String? {
        summary.participantDurations.max(by: { $0.value < $1.value })?.key
    }

    var longestParticipantName: String {
        guard let id = longestParticipantID else { return "—" }

        let name = participantMap[id]?.fullName ?? "Participant"
        return name.components(separatedBy: " ").first ?? name
    }

    var longestParticipantMinutes: Int {
        guard let id = longestParticipantID else { return 0 }
        return summary.participantDurations[id] ?? 0
    }

    // MARK: - 📊 FIX: Sorted Durations (STABLE)
    var sortedDurations: [(name: String, minutes: Int)] {
        summary.participantDurations
            .map { (userID, minutes) -> (String, Int) in
                let name = participantMap[userID]?.fullName ?? "Participant"
                let short = name.components(separatedBy: " ").first ?? name
                return (short, minutes)
            }
            .sorted { $0.1 > $1.1 }
    }
}
