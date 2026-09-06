//
//  Thread.swift
//  SpotFinder
//
//  A 1:1 conversation thread between two users.
//

import Foundation
import FirebaseFirestore

struct Thread: Identifiable, Codable {
    @DocumentID var id: String?
    var participantIds: [String]
    var lastMessageText: String?
    var lastMessageAt: Date?
    var lastMessageBy: String?
    
    init(id: String? = nil, participantIds: [String], lastMessageText: String? = nil, lastMessageAt: Date? = nil, lastMessageBy: String? = nil) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessageText = lastMessageText
        self.lastMessageAt = lastMessageAt
        self.lastMessageBy = lastMessageBy
    }
    
    /// Stable thread ID for two participants (sorted UIDs joined).
    static func threadId(between uid1: String, and uid2: String) -> String {
        [uid1, uid2].sorted().joined(separator: "_")
    }
    
    /// The other participant's UID from the current user's perspective.
    func otherParticipantId(currentUserId: String) -> String? {
        participantIds.first { $0 != currentUserId }
    }
}
