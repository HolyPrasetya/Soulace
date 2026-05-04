//
//  Constants.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation

struct AppConstants {

    // MARK: - Agora RTC
    struct Agora {
        // App ID Only mode — no certificate/token needed
        static let appID           = "9b3ac09daae24c1bbbe2a97753be127f"
        static let maxParticipants = 8
    }

    // MARK: - Session Duration Options
    struct Session {
        static let durationOptions: [Int] = [10, 15, 20, 30] // minutes
        static let defaultDuration: Int   = 20
    }

    // MARK: - Firestore Collections
    struct Collections {
        static let users       = "users"
        static let groups      = "groups"
        static let sessions    = "sessions"
        static let videos      = "videos"
        static let waitingRoom = "waitingRoom"
    }

    // MARK: - Mock Video URLs
    struct MockVideos {
        static let streamURLPlaceholder = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    }
}
