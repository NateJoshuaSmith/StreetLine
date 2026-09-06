//
//  Message.swift
//  SpotFinder
//
//  A single message in a thread.
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var createdAt: Date
    
    init(id: String? = nil, senderId: String, text: String, createdAt: Date = Date()) {
        self.id = id
        self.senderId = senderId
        self.text = text
        self.createdAt = createdAt
    }
}
