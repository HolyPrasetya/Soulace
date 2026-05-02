//
//  CreateSessionViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation

// MARK: - CreateSessionViewModel
final class CreateSessionViewModel: ObservableObject {
    @Published var selectedGroup: YogaGroup? = nil
    @Published var selectedVideo: VideoContent? = nil
    @Published var selectedDuration: Int = AppConstants.Session.defaultDuration
    @Published var scheduledDate: Date = Date()
    @Published var scheduledTime: Date = Date()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var createdSession: YogaSession? = nil
    @Published var showVideoLibrary: Bool = false

    let groups: [YogaGroup]
    let durationOptions = AppConstants.Session.durationOptions
    let videos: [VideoContent]

    private let firestoreService    = FirestoreService.shared
    private let authService         = AuthService.shared
    private let calendarService     = CalendarService.shared
    private let notificationService = NotificationService.shared

    var canCreate: Bool {
        selectedGroup != nil
    }

    var scheduledDateTime: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        var combined = DateComponents()
        combined.year   = dateComponents.year
        combined.month  = dateComponents.month
        combined.day    = dateComponents.day
        combined.hour   = timeComponents.hour
        combined.minute = timeComponents.minute
        return calendar.date(from: combined) ?? Date()
    }

    init(groups: [YogaGroup]) {
        self.groups = groups
        self.selectedGroup = groups.first
        self.videos = FirestoreService.shared.getMockVideos()
    }

    // MARK: - Create Session
    @MainActor
    func createSession() async {
        guard let group = selectedGroup,
              let groupID = group.id,
              let userID = authService.currentUser?.id else { return }

        isLoading = true
        errorMessage = nil

        let session = YogaSession(
            groupID: groupID,
            groupName: group.name,
            hostID: userID,
            videoID: selectedVideo?.id,
            scheduledAt: scheduledDateTime,
            durationMinutes: selectedDuration
        )

        do {
            let sessionID = try await firestoreService.createSession(session)
            var created = session
            created = YogaSession(
                id: sessionID,
                groupID: groupID,
                groupName: group.name,
                hostID: userID,
                videoID: selectedVideo?.id,
                scheduledAt: scheduledDateTime,
                durationMinutes: selectedDuration,
                agoraChannelName: session.agoraChannelName
            )

            // Add to calendar
            let eventID = await calendarService.addSession(created, groupName: group.name)
            if let eventID {
                try await firestoreService.updateSessionStatus(id: sessionID, status: .scheduled)
                _ = eventID // store eventID if needed via update
            }

            // Schedule local notification
            notificationService.scheduleSessionReminder(session: created, groupName: group.name)

            createdSession = created
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
