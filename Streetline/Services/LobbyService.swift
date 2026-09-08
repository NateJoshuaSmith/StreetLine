//
//  LobbyService.swift
//  Streetline
//
//  Global lobby chat. Stored as comments on a reserved community post so it
//  uses the same Firestore rules as Skate With replies.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class LobbyService: ObservableObject {
    static let historyLimit = 80
    
    private let db = Firestore.firestore()
    
    private var messagesCollection: CollectionReference {
        db.collection("communityPosts")
            .document(CommunityPost.lobbyDocumentId)
            .collection("comments")
    }
    
    func send(text: String, username: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "LobbyService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let displayName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        try await createLobbyDocumentIfNeeded(uid: uid, username: displayName)
        
        let comment = CommunityComment(
            createdBy: uid,
            createdByUsername: displayName.isEmpty ? "Unknown" : displayName,
            text: trimmed,
            createdAt: Date()
        )
        try await messagesCollection.document().setData(from: comment)
    }
    
    func listenToMessages(
        onUpdate: @escaping ([LobbyMessage]) -> Void,
        onError: @escaping (String) -> Void
    ) -> () -> Void {
        let query = messagesCollection
            .order(by: "createdAt", descending: true)
            .limit(to: Self.historyLimit)
        
        let listener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("LobbyService listen error: \(error.localizedDescription)")
                Task { @MainActor in
                    onError(error.localizedDescription)
                }
                return
            }
            guard let snapshot else { return }
            let messages = snapshot.documents.compactMap { Self.decode($0) }
                .filter { !$0.isExpired && !UserService.isUserBlocked($0.senderId) }
                .sorted { $0.createdAt < $1.createdAt }
            Task { @MainActor in
                onUpdate(messages)
            }
            if snapshot.documents.contains(where: { Self.decode($0)?.isExpired == true }) {
                Task { await self.deleteExpiredMessages() }
            }
        }
        return { listener.remove() }
    }
    
    func deleteExpiredMessages() async {
        let cutoff = Timestamp(date: Date().addingTimeInterval(-LobbyMessage.lifetime))
        guard let snapshot = try? await messagesCollection
            .whereField("createdAt", isLessThan: cutoff)
            .limit(to: 40)
            .getDocuments() else { return }
        for doc in snapshot.documents {
            try? await doc.reference.delete()
        }
    }
    
    private func createLobbyDocumentIfNeeded(uid: String, username: String) async throws {
        let ref = db.collection("communityPosts").document(CommunityPost.lobbyDocumentId)
        let snapshot = try await ref.getDocument()
        guard !snapshot.exists else { return }
        
        let now = Date()
        try await ref.setData([
            "createdBy": uid,
            "createdByUsername": username.isEmpty ? "Lobby" : username,
            "text": "Lobby",
            "createdAt": Timestamp(date: now),
            "sessionAt": Timestamp(date: now),
            "sessionWhat": "Mixed",
            "locationText": "Lobby",
            "expiresAt": Timestamp(date: now.addingTimeInterval(60 * 60 * 24 * 365 * 10)),
            "isLobby": true
        ])
    }
    
    private static func decode(_ doc: QueryDocumentSnapshot) -> LobbyMessage? {
        let data = doc.data()
        let senderId = (data["createdBy"] as? String) ?? (data["senderId"] as? String)
        let text = data["text"] as? String
        guard let senderId, let text else { return nil }
        let username = (data["createdByUsername"] as? String) ?? (data["senderUsername"] as? String)
        let trimmedName = username?.trimmingCharacters(in: .whitespacesAndNewlines)
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return LobbyMessage(
            id: doc.documentID,
            senderId: senderId,
            senderUsername: (trimmedName?.isEmpty == false) ? trimmedName! : "Unknown",
            text: text,
            createdAt: createdAt
        )
    }
}
