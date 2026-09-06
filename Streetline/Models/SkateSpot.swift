//
//  SkateSpot.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import Foundation
import FirebaseFirestore

struct SkateSpot: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var latitude: Double
    var longitude: Double
    var comment: String
    var createdBy: String
    var createdByUsername: String?  // Display name; nil for spots created before username feature
    var createdAt: Date
    var updatedAt: Date
    var imageURL: String?      // Legacy single photo URL (kept for backward compatibility)
    var imageURLs: [String]?   // Multiple user-uploaded spot photos (Firebase Storage URLs)
    
    // Optional metadata for filtering and display
    var tags: [String]?
    var difficulty: String?
    var status: String?
    
    init(
        id: String? = nil,
        name: String,
        latitude: Double,
        longitude: Double,
        comment: String,
        createdBy: String,
        createdByUsername: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        imageURL: String? = nil,
        imageURLs: [String]? = nil,
        tags: [String]? = nil,
        difficulty: String? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.comment = comment
        self.createdBy = createdBy
        self.createdByUsername = createdByUsername
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageURL = imageURL
        self.imageURLs = imageURLs
        self.tags = tags
        self.difficulty = difficulty
        self.status = status
    }
    
    /// First photo URL for map/list previews (prefers `imageURLs`, then legacy `imageURL`).
    var primaryImageURLString: String? {
        if let urls = imageURLs {
            if let first = urls.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                return first
            }
        }
        if let u = imageURL, !u.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return u
        }
        return nil
    }
}

