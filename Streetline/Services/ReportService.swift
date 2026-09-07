//
//  ReportService.swift
//  Streetline
//
//  Handles submitting reports for spots, posts, comments, messages, and users.
//

import Foundation
import Combine
import FirebaseFirestore

class ReportService: ObservableObject {
    private let authService = AuthService()
    private let userService = UserService()
    private let db = Firestore.firestore()
    private let collectionName = "reports"
    
    static let reportReasons: [(id: String, label: String)] = [
        ("inappropriate", "Inappropriate content"),
        ("spam", "Spam"),
        ("harassment", "Harassment or bullying"),
        ("wrong_location", "Wrong location"),
        ("offensive", "Offensive or harmful"),
        ("other", "Other")
    ]
    
    /// Submit a report for a spot. Requires the user to be logged in.
    func submitReport(spotId: String, spotName: String, reason: String, comment: String?) async throws {
        try await submitContentReport(
            type: .spot,
            targetId: spotId,
            targetPreview: spotName,
            reportedUserId: "",
            reason: reason,
            comment: comment,
            spotId: spotId,
            spotName: spotName
        )
    }
    
    func submitContentReport(
        type: ReportTargetType,
        targetId: String,
        targetPreview: String?,
        reportedUserId: String,
        reason: String,
        comment: String?,
        spotId: String? = nil,
        spotName: String? = nil
    ) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "ReportService", code: 401, userInfo: [NSLocalizedDescriptionKey: "You must be signed in to report"])
        }
        let username = await userService.getCurrentUsername()
        let trimmed = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let report = ContentReport(
            type: type,
            targetId: targetId,
            targetPreview: targetPreview,
            reportedUserId: reportedUserId,
            reportedBy: uid,
            reportedByUsername: username,
            reason: reason,
            comment: trimmed?.isEmpty == true ? nil : trimmed,
            spotId: spotId,
            spotName: spotName
        )
        try db.collection(collectionName).addDocument(from: report)
    }
}
