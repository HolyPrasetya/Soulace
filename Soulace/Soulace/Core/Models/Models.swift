//
//  Models.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import FirebaseFirestore

// MARK: - User
struct SoulaceUser: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var fullName:             String
    var email:                String
    var avatarURL:            String?
    var appleUserIdentifier:  String
    var groupIDs:             [String]
    var createdAt:            Timestamp   // ← Timestamp not Date (Firestore native)

    // MARK: Computed
    var initials: String {
        fullName.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
            .uppercased()
    }

    init(id: String?             = nil,
         fullName: String,
         email: String,
         avatarURL: String?      = nil,
         appleUserIdentifier: String,
         groupIDs: [String]      = [],
         createdAt: Timestamp    = Timestamp(date: Date())) {
        self.id                 = id
        self.fullName           = fullName
        self.email              = email
        self.avatarURL          = avatarURL
        self.appleUserIdentifier = appleUserIdentifier
        self.groupIDs           = groupIDs
        self.createdAt          = createdAt
    }
}

// MARK: - Group
struct YogaGroup: Identifiable, Codable {
    @DocumentID var id: String?
    var name:             String
    var description:      String
    var creatorID:        String
    var memberIDs:        [String]
    var inviteCode:       String
    var createdAt:        Timestamp
    var upcomingSessions: [String]

    var memberCount: Int { memberIDs.count }

    init(id: String?                  = nil,
         name: String,
         description: String,
         creatorID: String,
         memberIDs: [String]          = [],
         inviteCode: String           = String(UUID().uuidString.prefix(8)).uppercased(),
         createdAt: Timestamp         = Timestamp(date: Date()),
         upcomingSessions: [String]   = []) {
        self.id               = id
        self.name             = name
        self.description      = description
        self.creatorID        = creatorID
        self.memberIDs        = memberIDs
        self.inviteCode       = inviteCode
        self.createdAt        = createdAt
        self.upcomingSessions = upcomingSessions
    }
}

// MARK: - Yoga Session
struct YogaSession: Identifiable, Codable {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    @DocumentID var id: String?
    var groupID:           String
    var groupName:         String
    var hostID:            String
    var videoID:           String?
    var scheduledAt:       Timestamp
    var durationMinutes:   Int
    var status:            SessionStatus
    var participantIDs:    [String]
    var agoraChannelName:  String
    var calendarEventID:   String?

    enum SessionStatus: String, Codable {
        case scheduled, live, completed, cancelled
    }

    // MARK: Computed
    var scheduledDate: Date { scheduledAt.dateValue() }

    var endDate: Date {
        scheduledDate.addingTimeInterval(Double(durationMinutes) * 60)
    }

    var timeRangeString: String {
        "\(Self.timeFormatter.string(from: scheduledDate)) - \(Self.timeFormatter.string(from: endDate))"
    }

    init(id: String?               = nil,
         groupID: String,
         groupName: String,
         hostID: String,
         videoID: String?          = nil,
         scheduledAt: Timestamp    = Timestamp(date: Date()),
         durationMinutes: Int,
         status: SessionStatus     = .scheduled,
         participantIDs: [String]  = [],
         agoraChannelName: String  = UUID().uuidString,
         calendarEventID: String?  = nil) {
        self.id                = id
        self.groupID           = groupID
        self.groupName         = groupName
        self.hostID            = hostID
        self.videoID           = videoID
        self.scheduledAt       = scheduledAt
        self.durationMinutes   = durationMinutes
        self.status            = status
        self.participantIDs    = participantIDs
        self.agoraChannelName  = agoraChannelName
        self.calendarEventID   = calendarEventID
    }
}

// MARK: - Video Content
struct VideoContent: Identifiable, Codable {
    @DocumentID var id: String?
    var title:           String
    var instructorName:  String
    var durationMinutes: Int
    var level:           VideoLevel
    var category:        VideoCategory
    var thumbnailURL:    String
    var streamURL:       String
    var description:     String
    var tags:            [String]
    var uploadedAt:      Timestamp

    enum VideoLevel: String, Codable, CaseIterable {
        case beginner     = "Beginner"
        case intermediate = "Intermediate"
        case advanced     = "Advanced"
    }

    enum VideoCategory: String, Codable, CaseIterable {
        case morningFlow = "Morning Flow"
        case powerYoga   = "Power Yoga"
        case yin         = "Yin"
        case meditation  = "Meditation"
        case stretching  = "Stretching"
        case breathwork  = "Breathwork"
    }

    var levelColor: String {
        switch level {
        case .beginner:     return "4A7C6F"
        case .intermediate: return "C07800"
        case .advanced:     return "B53B3B"
        }
    }
}

// MARK: - Waiting Room Entry
struct WaitingEntry: Identifiable, Codable {
    @DocumentID var id: String?
    var sessionID:   String
    var userID:      String
    var userName:    String
    var userInitials: String
    var requestedAt: Timestamp
    var status:      WaitingStatus

    enum WaitingStatus: String, Codable {
        case pending, admitted, declined
    }
}

// MARK: - Call Participant (in-memory only, not persisted)
struct CallParticipant: Identifiable {
    let id:          String
    let agoraUID:    UInt
    var name:        String
    var initials:    String
    var isMuted:     Bool  = false
    var isCameraOff: Bool  = false
    var isHost:      Bool  = false
    var joinedAt:    Date  = Date()
}

// MARK: - Session Summary (in-memory only)
struct SessionSummary {
    var session:               YogaSession
    var participants:          [SoulaceUser]
    var participantDurations:  [String: Int]  // userID → minutes
    var longestParticipant:    SoulaceUser?
    var totalMinutes:          Int
}
