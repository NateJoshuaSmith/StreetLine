//
//  ContentReport.swift
//  Streetline
//
//  User reports for spots, posts, comments, messages, and accounts.
//

import Foundation
import FirebaseFirestore

enum ReportTargetType: String, Codable {
    case spot
    case communityPost
    case communityComment
    case spotComment
    case spotClip
    case message
    case user
}

struct ContentReport: Codable {
    @DocumentID var id: String?
    var type: String
    var targetId: String
    var targetPreview: String?
    var reportedUserId: String
    var reportedBy: String
    var reportedByUsername: String?
    var reason: String
    var comment: String?
    var createdAt: Date
    var spotId: String?
    var spotName: String?
    
    init(
        type: ReportTargetType,
        targetId: String,
        targetPreview: String? = nil,
        reportedUserId: String,
        reportedBy: String,
        reportedByUsername: String? = nil,
        reason: String,
        comment: String? = nil,
        createdAt: Date = Date(),
        spotId: String? = nil,
        spotName: String? = nil
    ) {
        self.type = type.rawValue
        self.targetId = targetId
        self.targetPreview = targetPreview
        self.reportedUserId = reportedUserId
        self.reportedBy = reportedBy
        self.reportedByUsername = reportedByUsername
        self.reason = reason
        self.comment = comment
        self.createdAt = createdAt
        self.spotId = spotId
        self.spotName = spotName
    }
}
