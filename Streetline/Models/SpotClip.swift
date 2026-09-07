//
//  SpotClip.swift
//  Streetline
//
//  A trick clip filmed at a skate spot.
//

import Foundation
import FirebaseFirestore

struct SpotClip: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var videoURL: String
    var thumbnailURL: String?
    var createdBy: String
    var createdByUsername: String?
    var createdAt: Date
    var caption: String?
    
    init(
        id: String? = nil,
        videoURL: String,
        thumbnailURL: String? = nil,
        createdBy: String,
        createdByUsername: String? = nil,
        createdAt: Date = Date(),
        caption: String? = nil
    ) {
        self.id = id
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.createdBy = createdBy
        self.createdByUsername = createdByUsername
        self.createdAt = createdAt
        self.caption = caption
    }
}
