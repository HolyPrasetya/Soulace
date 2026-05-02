//
//  FirestoreService.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - FirestoreService
final class FirestoreService {
    static let shared = FirestoreService()
    private let db    = Firestore.firestore()

    private init() {
        // Enable Firestore offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        db.settings = settings
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: USERS
    // MARK: ─────────────────────────────────────────────

    func getUser(id: String) async throws -> SoulaceUser? {
        let doc = try await db
            .collection(AppConstants.Collections.users)
            .document(id)
            .getDocument()

        // Document doesn't exist yet — return nil (not an error)
        guard doc.exists else { return nil }

        return try doc.data(as: SoulaceUser.self)
    }

    func createUser(_ user: SoulaceUser) async throws {
        guard let id = user.id else {
            throw FirestoreError.missingID
        }
        // Use setData with merge:false to create fresh document
        try await db
            .collection(AppConstants.Collections.users)
            .document(id)
            .setData(from: user)
    }

    func updateUser(_ user: SoulaceUser) async throws {
        guard let id = user.id else { return }
        try await db
            .collection(AppConstants.Collections.users)
            .document(id)
            .setData(from: user, merge: true)
    }

    func searchUsers(query: String) async throws -> [SoulaceUser] {
        let snapshot = try await db
            .collection(AppConstants.Collections.users)
            .whereField("fullName", isGreaterThanOrEqualTo: query)
            .whereField("fullName", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: SoulaceUser.self)
        }
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: GROUPS
    // MARK: ─────────────────────────────────────────────

    func createGroup(_ group: YogaGroup) async throws -> String {
        let ref = try db
            .collection(AppConstants.Collections.groups)
            .addDocument(from: group)
        return ref.documentID
    }

    func getGroup(id: String) async throws -> YogaGroup? {
        let doc = try await db
            .collection(AppConstants.Collections.groups)
            .document(id)
            .getDocument()
        guard doc.exists else { return nil }
        return try? doc.data(as: YogaGroup.self)
    }

    func getGroupByInviteCode(_ code: String) async throws -> YogaGroup? {
        let snapshot = try await db
            .collection(AppConstants.Collections.groups)
            .whereField("inviteCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.first.flatMap { try? $0.data(as: YogaGroup.self) }
    }

    func getUserGroups(userID: String) -> AnyPublisher<[YogaGroup], Error> {
        let subject = PassthroughSubject<[YogaGroup], Error>()
        db.collection(AppConstants.Collections.groups)
            .whereField("memberIDs", arrayContains: userID)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }
                let groups = (snapshot?.documents ?? [])
                    .compactMap { try? $0.data(as: YogaGroup.self) }
                subject.send(groups)
            }
        return subject.eraseToAnyPublisher()
    }

    func addUserToGroup(groupID: String, userID: String) async throws {
        // Add userID to group's memberIDs
        try await db
            .collection(AppConstants.Collections.groups)
            .document(groupID)
            .updateData(["memberIDs": FieldValue.arrayUnion([userID])])

        // Add groupID to user's groupIDs
        try await db
            .collection(AppConstants.Collections.users)
            .document(userID)
            .updateData(["groupIDs": FieldValue.arrayUnion([groupID])])
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: SESSIONS
    // MARK: ─────────────────────────────────────────────

    func createSession(_ session: YogaSession) async throws -> String {
        let ref = try db
            .collection(AppConstants.Collections.sessions)
            .addDocument(from: session)

        // Link session to group
        try await db
            .collection(AppConstants.Collections.groups)
            .document(session.groupID)
            .updateData(["upcomingSessions": FieldValue.arrayUnion([ref.documentID])])

        return ref.documentID
    }

    func getSession(id: String) async throws -> YogaSession? {
        let doc = try await db
            .collection(AppConstants.Collections.sessions)
            .document(id)
            .getDocument()
        guard doc.exists else { return nil }
        return try? doc.data(as: YogaSession.self)
    }

    func getUpcomingSessions(groupID: String) -> AnyPublisher<[YogaSession], Error> {
        let subject = PassthroughSubject<[YogaSession], Error>()
        db.collection(AppConstants.Collections.sessions)
            .whereField("groupID", isEqualTo: groupID)
            .whereField("status",  isEqualTo: "scheduled")
            .order(by: "scheduledAt")
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }
                let sessions = (snapshot?.documents ?? [])
                    .compactMap { try? $0.data(as: YogaSession.self) }
                subject.send(sessions)
            }
        return subject.eraseToAnyPublisher()
    }

    func updateSessionStatus(id: String, status: YogaSession.SessionStatus) async throws {
        try await db
            .collection(AppConstants.Collections.sessions)
            .document(id)
            .updateData(["status": status.rawValue])
    }

    func addParticipantToSession(sessionID: String, userID: String) async throws {
        try await db
            .collection(AppConstants.Collections.sessions)
            .document(sessionID)
            .updateData(["participantIDs": FieldValue.arrayUnion([userID])])
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: WAITING ROOM
    // MARK: ─────────────────────────────────────────────

    func addToWaitingRoom(_ entry: WaitingEntry) async throws -> String {
        let ref = try db
            .collection(AppConstants.Collections.waitingRoom)
            .addDocument(from: entry)
        return ref.documentID
    }

    func observeWaitingRoom(sessionID: String) -> AnyPublisher<[WaitingEntry], Error> {
        let subject = PassthroughSubject<[WaitingEntry], Error>()
        db.collection(AppConstants.Collections.waitingRoom)
            .whereField("sessionID", isEqualTo: sessionID)
            .whereField("status",    isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }
                let entries = (snapshot?.documents ?? [])
                    .compactMap { try? $0.data(as: WaitingEntry.self) }
                subject.send(entries)
            }
        return subject.eraseToAnyPublisher()
    }

    func observeMyWaitingStatus(entryID: String) -> AnyPublisher<WaitingEntry?, Error> {
        let subject = PassthroughSubject<WaitingEntry?, Error>()
        db.collection(AppConstants.Collections.waitingRoom)
            .document(entryID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }
                let entry = try? snapshot?.data(as: WaitingEntry.self)
                subject.send(entry)
            }
        return subject.eraseToAnyPublisher()
    }

    func updateWaitingStatus(entryID: String, status: WaitingEntry.WaitingStatus) async throws {
        try await db
            .collection(AppConstants.Collections.waitingRoom)
            .document(entryID)
            .updateData(["status": status.rawValue])
    }

    // MARK: ─────────────────────────────────────────────
    // MARK: VIDEO LIBRARY
    // MARK: ─────────────────────────────────────────────

    func getVideos(category: VideoContent.VideoCategory? = nil) async throws -> [VideoContent] {
        var query: Query = db
            .collection(AppConstants.Collections.videos)
            .order(by: "uploadedAt", descending: true)

        if let category {
            query = query.whereField("category", isEqualTo: category.rawValue)
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: VideoContent.self) }
    }

    /// Mock videos for development — replace when real content is in Firebase Storage
    func getMockVideos() -> [VideoContent] {
        let now = Timestamp(date: Date())
        return [
            VideoContent(
                id: "v1", title: "20 Min Morning Flow",
                instructorName: "Yoga with Adriene",
                durationMinutes: 20, level: .beginner,
                category: .morningFlow,
                thumbnailURL: "", streamURL: AppConstants.MockVideos.streamURLPlaceholder,
                description: "Start your morning with this gentle flow.",
                tags: ["morning", "gentle", "full-body"], uploadedAt: now
            ),
            VideoContent(
                id: "v2", title: "Power Yoga 30 Min",
                instructorName: "Breathe and Flow",
                durationMinutes: 30, level: .intermediate,
                category: .powerYoga,
                thumbnailURL: "", streamURL: AppConstants.MockVideos.streamURLPlaceholder,
                description: "Build strength and flexibility.",
                tags: ["power", "strength", "core"], uploadedAt: now
            ),
            VideoContent(
                id: "v3", title: "Yin Yoga Deep Stretch",
                instructorName: "Sarah Beth Yoga",
                durationMinutes: 15, level: .beginner,
                category: .yin,
                thumbnailURL: "", streamURL: AppConstants.MockVideos.streamURLPlaceholder,
                description: "Deep relaxing yin poses.",
                tags: ["yin", "relax", "stretch"], uploadedAt: now
            ),
            VideoContent(
                id: "v4", title: "Evening Wind Down",
                instructorName: "Yoga with Adriene",
                durationMinutes: 10, level: .beginner,
                category: .stretching,
                thumbnailURL: "", streamURL: AppConstants.MockVideos.streamURLPlaceholder,
                description: "Gentle evening stretches.",
                tags: ["evening", "relax", "gentle"], uploadedAt: now
            )
        ]
    }
}

// MARK: - Firestore Errors
enum FirestoreError: LocalizedError {
    case missingID
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingID:       return "Document ID is missing"
        case .decodingFailed:  return "Failed to decode document"
        }
    }
}
