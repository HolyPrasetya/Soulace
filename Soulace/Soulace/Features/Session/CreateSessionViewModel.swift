//
//  CreateSessionViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - CreateSessionViewModel
final class CreateSessionViewModel: ObservableObject {
    @Published var selectedGroup:    YogaGroup?      = nil
    @Published var selectedVideo:    VideoContent?   = nil
    @Published var selectedDuration: Int             = AppConstants.Session.defaultDuration
    @Published var scheduledDate:    Date            = Date()
    @Published var scheduledTime:    Date            = Date()
    @Published var isLoading:        Bool            = false
    @Published var errorMessage:     String?         = nil
    @Published var createdSession:   YogaSession?    = nil
    @Published var showVideoLibrary: Bool            = false

    let groups:          [YogaGroup]
    let durationOptions: [Int]       = AppConstants.Session.durationOptions
    let videos:          [VideoContent]

    private let firestoreService    = FirestoreService.shared
    private let authService         = AuthService.shared
    private let calendarService     = CalendarService.shared
    private let notificationService = NotificationService.shared
    private var cancellables        = Set<AnyCancellable>()

    var canCreate: Bool { selectedGroup != nil }

    /// Combined date + time picker values → single Date → Firestore Timestamp
    var scheduledTimestamp: Timestamp {
        let calendar = Calendar.current
        let dateComps = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
        let timeComps = calendar.dateComponents([.hour, .minute],      from: scheduledTime)
        var combined  = DateComponents()
        combined.year   = dateComps.year
        combined.month  = dateComps.month
        combined.day    = dateComps.day
        combined.hour   = timeComps.hour
        combined.minute = timeComps.minute
        let date = calendar.date(from: combined) ?? Date()
        return Timestamp(date: date)
    }

    init(groups: [YogaGroup]) {
        self.groups        = groups
        self.selectedGroup = groups.first
        self.videos        = FirestoreService.shared.getMockVideos()
    }

    // MARK: - Create Session
    @MainActor
    func createSession() async {
        guard let group  = selectedGroup,
              let groupID = group.id,
              let userID  = authService.currentUser?.id else { return }

        isLoading    = true
        errorMessage = nil

        let session = YogaSession(
            groupID:          groupID,
            groupName:        group.name,
            hostID:           userID,
            videoID:          selectedVideo?.id,
            scheduledAt:      scheduledTimestamp,
            durationMinutes:  selectedDuration
        )

        do {
            let sessionID = try await firestoreService.createSession(session)

            var created   = session
            // Rebuild with ID
            created = YogaSession(
                id:               sessionID,
                groupID:          groupID,
                groupName:        group.name,
                hostID:           userID,
                videoID:          selectedVideo?.id,
                scheduledAt:      scheduledTimestamp,
                durationMinutes:  selectedDuration,
                agoraChannelName: session.agoraChannelName
            )

            // Add to native Calendar
            _ = await calendarService.addSession(created, groupName: group.name)

            // Schedule local notification reminder
            notificationService.scheduleSessionReminder(
                session:   created,
                groupName: group.name
            )

            createdSession = created

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
