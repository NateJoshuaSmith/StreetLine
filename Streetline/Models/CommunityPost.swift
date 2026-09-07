//
//  CommunityPost.swift
//  SpotFinder
//
//  Forum-style post for finding skate sessions.
//

import Foundation
import FirebaseFirestore

struct CommunityPost: Identifiable, Codable {
    @DocumentID var id: String?
    var createdBy: String
    var createdByUsername: String
    var text: String
    var createdAt: Date
    /// When they want to skate.
    var sessionAt: Date?
    /// Street, Park, DIY, Bowl, Mini, or Mixed.
    var sessionWhat: String?
    var spotId: String?
    var spotName: String?
    /// Custom place if they didn't pick a map spot.
    var locationText: String?
    /// Hidden after this time (session time + 24 hours).
    var expiresAt: Date?
    
    static let sessionTypes = ["Street", "Park", "DIY", "Bowl", "Mini", "Mixed"]
    static let lifetime: TimeInterval = 24 * 60 * 60
    static let lobbyDocumentId = "lobby"
    
    init(
        id: String? = nil,
        createdBy: String,
        createdByUsername: String,
        text: String,
        createdAt: Date = Date(),
        sessionAt: Date? = nil,
        sessionWhat: String? = nil,
        spotId: String? = nil,
        spotName: String? = nil,
        locationText: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.createdBy = createdBy
        self.createdByUsername = createdByUsername
        self.text = text
        self.createdAt = createdAt
        self.sessionAt = sessionAt
        self.sessionWhat = sessionWhat
        self.spotId = spotId
        self.spotName = spotName
        self.locationText = locationText
        self.expiresAt = expiresAt
    }
    
    var displayWhere: String? {
        if let spotName, !spotName.isEmpty { return spotName }
        if let locationText, !locationText.isEmpty { return locationText }
        return nil
    }
    
    var displayWhen: Date {
        sessionAt ?? createdAt
    }
    
    var isExpired: Bool {
        let end = expiresAt ?? displayWhen.addingTimeInterval(Self.lifetime)
        return Date() >= end
    }
    
    var formattedWhen: String {
        let date = displayWhen
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "Today, \(time)" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow, \(time)" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
