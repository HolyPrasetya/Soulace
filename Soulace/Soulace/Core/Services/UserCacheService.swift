//
//  UserCacheService.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 05/05/26.
//

import Foundation

final class UserCacheService {
    static let shared = UserCacheService()

    private var cache: [String: SoulaceUser] = [:]
    private let firestore = FirestoreService.shared

    private init() {}

    func getUser(id: String) async -> SoulaceUser? {
        if let cached = cache[id] {
            return cached
        }

        do {
            if let user = try await firestore.getUser(id: id) {
                cache[id] = user
                return user
            }
        } catch {
            print("❌ Failed fetch user:", error.localizedDescription)
        }

        return nil
    }

    func preloadUsers(ids: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask {
                    _ = await self.getUser(id: id)
                }
            }
        }
    }
}
