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
    let db = Firestore.firestore()

    private init() {
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
    }

    // MARK: ── USERS ──

    func getUser(id: String) async throws -> SoulaceUser? {
        let doc = try await db
            .collection(AppConstants.Collections.users)
            .document(id)
            .getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: SoulaceUser.self)
    }

    func createUser(_ user: SoulaceUser) async throws {
        guard let id = user.id else { throw FirestoreError.missingID }
        try db
            .collection(AppConstants.Collections.users)
            .document(id)
            .setData(from: user)
    }

    func updateUser(_ user: SoulaceUser) async throws {
        guard let id = user.id else { return }
        try db
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
        return snapshot.documents.compactMap { try? $0.data(as: SoulaceUser.self) }
    }

    // Cari users berdasarkan email (untuk contact sync)
    func getUsersByEmails(_ emails: [String]) async throws -> [SoulaceUser] {
        guard !emails.isEmpty else { return [] }
        let snapshot = try await db
            .collection(AppConstants.Collections.users)
            .whereField("email", in: emails)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: SoulaceUser.self) }
    }

    // MARK: ── GROUPS ──

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
        try await db
            .collection(AppConstants.Collections.groups)
            .document(groupID)
            .updateData(["memberIDs": FieldValue.arrayUnion([userID])])

        try await db
            .collection(AppConstants.Collections.users)
            .document(userID)
            .updateData(["groupIDs": FieldValue.arrayUnion([groupID])])
    }

    // MARK: ── DELETE / LEAVE GROUP ──

    /// Delete group entirely (creator only) + remove from all members' groupIDs
    func deleteGroup(groupID: String, memberIDs: [String]) async throws {
        // 1. Remove groupID from every member's groupIDs array
        for memberID in memberIDs {
            try await db
                .collection(AppConstants.Collections.users)
                .document(memberID)
                .updateData(["groupIDs": FieldValue.arrayRemove([groupID])])
        }

        // 2. Delete all sessions belonging to this group
        let sessionsSnapshot = try await db
            .collection(AppConstants.Collections.sessions)
            .whereField("groupID", isEqualTo: groupID)
            .getDocuments()

        for doc in sessionsSnapshot.documents {
            try await doc.reference.delete()
        }

        // 3. Delete the group document itself
        try await db
            .collection(AppConstants.Collections.groups)
            .document(groupID)
            .delete()

        print("🗑️ Firestore: group \(groupID) deleted")
    }

    /// Leave group (non-creator) — only removes user from memberIDs
    func leaveGroup(groupID: String, userID: String) async throws {
        try await db
            .collection(AppConstants.Collections.groups)
            .document(groupID)
            .updateData(["memberIDs": FieldValue.arrayRemove([userID])])

        try await db
            .collection(AppConstants.Collections.users)
            .document(userID)
            .updateData(["groupIDs": FieldValue.arrayRemove([groupID])])

        print("🚪 Firestore: user \(userID) left group \(groupID)")
    }

    // MARK: ── SESSIONS ──

    func createSession(_ session: YogaSession) async throws -> String {
        let ref = try db
            .collection(AppConstants.Collections.sessions)
            .addDocument(from: session)

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

    // FIX: Query hanya by groupID — filter status & date di client side
    // Ini menghindari kebutuhan composite index yang mungkin belum dibuat
    func getUpcomingSessions(groupID: String) -> AnyPublisher<[YogaSession], Error> {
        let subject = PassthroughSubject<[YogaSession], Error>()

        db.collection(AppConstants.Collections.sessions)
            .whereField("groupID", isEqualTo: groupID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }

                let now = Date()
                let sessions = (snapshot?.documents ?? [])
                    .compactMap { try? $0.data(as: YogaSession.self) }
                    // Filter di client: hanya scheduled atau live, dan belum lewat
                    .filter { session in
                        let isActiveStatus = session.status == .scheduled || session.status == .live
                        let isNotExpired   = session.endDate > now
                        return isActiveStatus && isNotExpired
                    }
                    .sorted { $0.scheduledDate < $1.scheduledDate }

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

    // MARK: ── WAITING ROOM ──

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
            .whereField("status", isEqualTo: "pending")
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

    // MARK: ── VIDEO LIBRARY ──

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

    // MARK: - Local Video Bundle URL helper
    private func bundleVideoURL(_ filename: String) -> String {
        if let url = Bundle.main.url(forResource: filename, withExtension: "mp4") {
            return url.absoluteString
        }
        print("Video file '\(filename).mp4' not found in bundle")
        return AppConstants.MockVideos.streamURLPlaceholder
    }

    func getMockVideos() -> [VideoContent] {
        let now = Timestamp(date: Date())
        return [
            VideoContent(id: "v1", title: "10 Minute Yoga",
                instructorName: "Soulace", durationMinutes: 10,
                level: .beginner, category: .stretching,
                thumbnailURL: "", streamURL: bundleVideoURL("10MinuteYoga"),
                description: "A quick 10-minute yoga flow perfect for any time of day.",
                tags: ["quick", "beginner", "warm-up"], uploadedAt: now),
            VideoContent(id: "v2", title: "15 Minute Yoga",
                instructorName: "Soulace", durationMinutes: 15,
                level: .beginner, category: .morningFlow,
                thumbnailURL: "", streamURL: bundleVideoURL("15MinuteYoga"),
                description: "A gentle 15-minute morning flow to wake up your body.",
                tags: ["morning", "gentle", "flow"], uploadedAt: now),
            VideoContent(id: "v3", title: "20 Minute Yoga",
                instructorName: "Soulace", durationMinutes: 20,
                level: .intermediate, category: .morningFlow,
                thumbnailURL: "", streamURL: bundleVideoURL("20MinuteYoga"),
                description: "A balanced 20-minute full-body yoga session.",
                tags: ["full-body", "strength", "flexibility"], uploadedAt: now),
            VideoContent(id: "v4", title: "30 Minute Yoga",
                instructorName: "Soulace", durationMinutes: 30,
                level: .intermediate, category: .powerYoga,
                thumbnailURL: "", streamURL: bundleVideoURL("30MinuteYoga"),
                description: "A complete 30-minute power yoga session.",
                tags: ["power", "endurance", "deep-stretch"], uploadedAt: now)
        ]
    }
}

// MARK: - Firestore Errors
enum FirestoreError: LocalizedError {
    case missingID
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingID:      return "Document ID is missing"
        case .decodingFailed: return "Failed to decode document"
        }
    }
}
