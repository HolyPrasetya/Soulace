//
//  NotificationService.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Combine
import Foundation
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

// MARK: - NotificationService
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published var fcmToken: String? = nil

    override init() {
        super.init()
#if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
#endif
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Request Permission
    func requestPermission() async -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: options)) ?? false
    }

    // MARK: - Subscribe to Group Topic
    /// Subscribe to FCM topic so all group members get notified
    func subscribeToGroup(_ groupID: String) {
#if canImport(FirebaseMessaging)
        Messaging.messaging().subscribe(toTopic: "group_\(groupID)")
#endif
    }

    func unsubscribeFromGroup(_ groupID: String) {
#if canImport(FirebaseMessaging)
        Messaging.messaging().unsubscribe(fromTopic: "group_\(groupID)")
#endif
    }

    // MARK: - Local Notification (for session reminders)
    func scheduleSessionReminder(session: YogaSession, groupName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🧘 Yoga session starting soon!"
        content.body  = "\(groupName) session starts in 10 minutes"
        content.sound = .default

        // 10 min before
        let triggerDate = session.scheduledDate.addingTimeInterval(-600)
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session_\(session.id ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelSessionReminder(sessionID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["session_\(sessionID)"]
        )
    }
}

#if canImport(FirebaseMessaging)
// MARK: - MessagingDelegate
extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async { self.fcmToken = fcmToken }
    }
}
#endif

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
}
