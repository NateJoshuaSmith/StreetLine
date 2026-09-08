//
//  UserProfile.swift
//  SpotFinder
//
//  Created for username display feature.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable {
    var uid: String
    var username: String
    var email: String?
    var avatarURL: String?
    var createdAt: Date?
    var age: Int?
    var skillLevel: String?
    var favoriteTrick: String?
    var favoriteSkater: String?
    
    static let skillLevels = ["Beginner", "Intermediate", "Advanced"]
    
    var hasSkateDetails: Bool {
        age != nil
            || !(skillLevel ?? "").isEmpty
            || !(favoriteTrick ?? "").isEmpty
            || !(favoriteSkater ?? "").isEmpty
    }

    init(
        uid: String,
        username: String,
        email: String? = nil,
        avatarURL: String? = nil,
        createdAt: Date? = nil,
        age: Int? = nil,
        skillLevel: String? = nil,
        favoriteTrick: String? = nil,
        favoriteSkater: String? = nil
    ) {
        self.uid = uid
        self.username = username
        self.email = email
        self.avatarURL = avatarURL
        self.createdAt = createdAt ?? Date()
        self.age = age
        self.skillLevel = skillLevel
        self.favoriteTrick = favoriteTrick
        self.favoriteSkater = favoriteSkater
    }
}
