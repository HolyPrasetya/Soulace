//
//  GroupInvitationService.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//


import Foundation
import FirebaseFirestore
import Combine

// MARK: - GroupInvitation Model
struct GroupInvitation: Identifiable, Codable {
    @DocumentID var id: String?
    var groupID:     String
    var groupName:   String
    var inviteCode:  String
    var fromUserID:  String
    var fromName:    String
    var toUserID:    String
    var status:      InviteStatus
    var createdAt:   Timestamp

    enum InviteStatus: String, Codable {
        case pending, accepted, declined
    }
}

// MARK: - GroupInvitationService
final class GroupInvitationService {
    static let shared = GroupInvitationService()
    private let db = Firestore.firestore()
    private let collection = "groupInvitations"

    private init() {}

    // MARK: - Send invitation
    func sendInvitation(group: YogaGroup, fromUser: SoulaceUser, toUserID: String) async throws {
        guard let groupID   = group.id,
              let fromID    = fromUser.id else { return }

        // Cek sudah ada pending invite — query hanya toUserID+status (sesuai rules & index)
        let existing = try await db.collection(collection)
            .whereField("toUserID", isEqualTo: toUserID)
            .whereField("status",   isEqualTo: "pending")
            .getDocuments()

        // Filter groupID di client
        let alreadyInvited = existing.documents.compactMap { try? $0.data(as: GroupInvitation.self) }
            .contains { $0.groupID == groupID }
        if alreadyInvited { return }

        let invite = GroupInvitation(
            groupID:    groupID,
            groupName:  group.name,
            inviteCode: group.inviteCode,
            fromUserID: fromID,
            fromName:   fromUser.fullName,
            toUserID:   toUserID,
            status:     .pending,
            createdAt:  Timestamp(date: Date())
        )
        try db.collection(collection).addDocument(from: invite)
    }

    // MARK: - Observe pending invitations for current user (realtime)
    func observeInvitations(userID: String) -> AnyPublisher<[GroupInvitation], Error> {
        let subject = PassthroughSubject<[GroupInvitation], Error>()
        db.collection(collection)
            .whereField("toUserID", isEqualTo: userID)
            .whereField("status",   isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                if let error { subject.send(completion: .failure(error)); return }
                let invites = (snapshot?.documents ?? [])
                    .compactMap { try? $0.data(as: GroupInvitation.self) }
                subject.send(invites)
            }
        return subject.eraseToAnyPublisher()
    }

    // MARK: - Accept
    func accept(_ invitation: GroupInvitation) async throws {
        guard let inviteID = invitation.id else { return }

        // Add user to group
        try await FirestoreService.shared.addUserToGroup(
            groupID: invitation.groupID,
            userID:  invitation.toUserID
        )
        // Mark accepted
        try await db.collection(collection).document(inviteID)
            .updateData(["status": "accepted"])

        NotificationService.shared.subscribeToGroup(invitation.groupID)
    }

    // MARK: - Decline
    func decline(_ invitation: GroupInvitation) async throws {
        guard let inviteID = invitation.id else { return }
        try await db.collection(collection).document(inviteID)
            .updateData(["status": "declined"])
    }
}
