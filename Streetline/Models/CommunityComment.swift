//
//  CommunityComment.swift
//  SpotFinder
//
//  Comment/reply on a community post.
//

import Foundation
import FirebaseFirestore

struct CommunityComment: Identifiable, Codable {
    @DocumentID var id: String?
    var createdBy: String
    var createdByUsername: String
    var text: String
    var createdAt: Date
    
    init(
        id: String? = nil,
        createdBy: String,
        createdByUsername: String,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.createdBy = createdBy
        self.createdByUsername = createdByUsername
        self.text = text
        self.createdAt = createdAt
    }
}

