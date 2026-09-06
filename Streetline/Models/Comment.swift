//
//  Comment.swift
//  SpotFinder
//
//  Comments on skate spots with like/dislike support.
//

import Foundation
import FirebaseFirestore

struct SpotComment: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var text: String
    var createdBy: String
    var createdByUsername: String?
    var createdAt: Date
    var likedBy: [String]      // User IDs who liked
    var dislikedBy: [String]   // User IDs who disliked
    
    init(id: String? = nil, text: String, createdBy: String, createdByUsername: String? = nil, createdAt: Date = Date(), likedBy: [String] = [], dislikedBy: [String] = []) {
        self.id = id
        self.text = text
        self.createdBy = createdBy
        self.createdByUsername = createdByUsername
        self.createdAt = createdAt
        self.likedBy = likedBy
        self.dislikedBy = dislikedBy
    }
    
    var likeCount: Int { likedBy.count }
    var dislikeCount: Int { dislikedBy.count }
    
    func hasLiked(userId: String) -> Bool { likedBy.contains(userId) }
    func hasDisliked(userId: String) -> Bool { dislikedBy.contains(userId) }
}

