//
//  FriendRequest.swift
//  SpotFinder
//
//  A friend request from one user to another.
//

import Foundation
import FirebaseFirestore

struct FriendRequest: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUid: String
    var toUid: String
    var status: String // "pending", "accepted", "declined"
    var createdAt: Date
    
    /// Unique id for a request from one user to another (from_to).
    static func requestId(from: String, to: String) -> String {
        "\(from)_\(to)"
    }
    
    static let statusPending = "pending"
    static let statusAccepted = "accepted"
    static let statusDeclined = "declined"
}
