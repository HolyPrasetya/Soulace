//
//  CalendarService.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import EventKit

// MARK: - CalendarService
/// Integrates with native iOS Calendar via EventKit
final class CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()

    private init() {}

    // MARK: - Request Access
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await store.requestWriteOnlyAccessToEvents()) ?? false
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Add Session to Calendar
    /// Returns the EKEvent identifier to save in Firestore
    func addSession(_ session: YogaSession, groupName: String) async -> String? {
        let granted = await requestAccess()
        guard granted else { return nil }

        let event = EKEvent(eventStore: store)
        event.title    = "🧘 \(groupName) — Yoga Session"
        event.notes    = "Soulace yoga session • \(session.durationMinutes) minutes"
        event.startDate = session.scheduledDate
        event.endDate   = session.endDate
        event.calendar  = store.defaultCalendarForNewEvents

        // Reminder 10 minutes before
        event.addAlarm(EKAlarm(relativeOffset: -600))

        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("CalendarService: Failed to save event — \(error)")
            return nil
        }
    }

    // MARK: - Remove Session from Calendar
    func removeSession(eventID: String) async {
        let granted = await requestAccess()
        guard granted else { return }

        if let event = store.event(withIdentifier: eventID) {
            try? store.remove(event, span: .thisEvent)
        }
    }

    // MARK: - Update Session in Calendar
    func updateSession(_ session: YogaSession, eventID: String) async {
        let granted = await requestAccess()
        guard granted else { return }

        if let event = store.event(withIdentifier: eventID) {
            event.startDate = session.scheduledDate
            event.endDate   = session.endDate
            try? store.save(event, span: .thisEvent)
        }
    }
}
