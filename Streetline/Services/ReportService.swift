//
//  ReportService.swift
//  SpotFinder
//
//  Handles submitting reports for spots.
//

import Foundation
import Combine
import FirebaseFirestore

class ReportService: ObservableObject {
    private let authService = AuthService()
    private let userService = UserService()
    private let db = Firestore.firestore()
    private let collectionName = "reports"
    
    /// Predefined report reasons for the UI
    static let reportReasons: [(id: String, label: String)] = [
        ("inappropriate", "Inappropriate content"),
        ("spam", "Spam"),
        ("wrong_location", "Wrong location"),
        ("offensive", "Offensive or harmful"),
        ("other", "Other")
    ]
    
    /// Submit a report for a spot. Requires the user to be logged in.
    func submitReport(spotId: String, spotName: String, reason: String, comment: String?) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "ReportService", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be signed in to report"])
        }
        let username = await userService.getCurrentUsername()
        let report = SpotReport(
            spotId: spotId,
            spotName: spotName,
            reportedBy: uid,
            reportedByUsername: username,
            reason: reason,
            comment: comment?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try db.collection(collectionName).addDocument(from: report)
    }
}
