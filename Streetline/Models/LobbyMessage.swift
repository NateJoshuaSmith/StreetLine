//
//  LobbyMessage.swift
//  Streetline
//
//  A message in the global lobby chat.
//

import Foundation
import FirebaseFirestore

struct LobbyMessage: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var senderUsername: String
    var text: String
    var createdAt: Date
    
    static let lifetime: TimeInterval = 24 * 60 * 60
    
    init(
        id: String? = nil,
        senderId: String,
        senderUsername: String,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.senderId = senderId
        self.senderUsername = senderUsername
        self.text = text
        self.createdAt = createdAt
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) >= Self.lifetime
    }
}
