//
//  Constants.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation

struct AppConstants {

    // MARK: - Agora
    struct Agora {
        /// ⚠️ Regenerate your Primary Certificate after development
        static let appID        = "0879504a5ae84114a7caff552eb76d28"
        static let certificate  = "70c0843b8cb04a07be530690263a8c04" // regenerate this!
        static let maxParticipants = 8
    }

    // MARK: - Session
    struct Session {
        static let durationOptions: [Int] = [10, 15, 20, 30] // minutes
        static let defaultDuration: Int   = 20
    }

    // MARK: - Firestore Collections
    struct Collections {
        static let users    = "users"
        static let groups   = "groups"
        static let sessions = "sessions"
        static let videos   = "videos"
        static let waitingRoom = "waitingRoom"
    }

    // MARK: - Mock Video URLs (replace with real Firebase Storage URLs later)
    struct MockVideos {
        static let thumbnailPlaceholder = "https://via.placeholder.com/400x225/D1E3E3/2C3E35?text=Yoga"
        static let streamURLPlaceholder = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    }
}
