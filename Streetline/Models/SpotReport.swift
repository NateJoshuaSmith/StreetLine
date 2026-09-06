//
//  SpotReport.swift
//  SpotFinder
//
//  Model for user-submitted reports on spots.
//

import Foundation
import FirebaseFirestore

struct SpotReport: Codable {
    @DocumentID var id: String?
    var spotId: String
    var spotName: String
    var reportedBy: String
    var reportedByUsername: String?
    var reason: String
    var comment: String?
    var createdAt: Date
    
    init(
        id: String? = nil,
        spotId: String,
        spotName: String,
        reportedBy: String,
        reportedByUsername: String? = nil,
        reason: String,
        comment: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.spotId = spotId
        self.spotName = spotName
        self.reportedBy = reportedBy
        self.reportedByUsername = reportedByUsername
        self.reason = reason
        self.comment = comment
        self.createdAt = createdAt
    }
}
