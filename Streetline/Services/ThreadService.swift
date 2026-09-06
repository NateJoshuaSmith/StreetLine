//
//  ThreadService.swift
//  SpotFinder
//
//  Manages 1:1 chat threads and messages.
//

import Foundation
import FirebaseFirestore
import Combine

class ThreadService: ObservableObject {
    private let authService = AuthService()
    private let db = Firestore.firestore()
    private let threadsCollection = "threads"
    
    /// Create a thread with a friend (or return existing). Caller must be friends with the other user.
    func createOrGetThread(withFriendUid friendUid: String) async throws -> Thread {
        guard let currentUid = authService.currentUserId else {
            throw NSError(domain: "ThreadService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let threadId = Thread.threadId(between: currentUid, and: friendUid)
        let ref = db.collection(threadsCollection).document(threadId)
        let doc = try? await ref.getDocument()
        if let doc = doc, doc.exists, let thread = try? doc.data(as: Thread.self) {
            var t = thread
            t.id = threadId
            return t
        }
        let newThread = Thread(
            id: threadId,
            participantIds: [currentUid, friendUid].sorted(),
            lastMessageText: nil,
            lastMessageAt: nil,
            lastMessageBy: nil
        )
        var data = (try? Firestore.Encoder().encode(newThread)) ?? [:]
        data["participantIds"] = [currentUid, friendUid].sorted()
        try await ref.setData(data)
        return newThread
    }
    
    /// Send a text message in a thread.
    func sendMessage(threadId: String, text: String) async throws {
        guard let currentUid = authService.currentUserId else {
            throw NSError(domain: "ThreadService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = Message(senderId: currentUid, text: trimmed, createdAt: Date())
        let ref = db.collection(threadsCollection).document(threadId).collection("messages").document()
        try ref.setData(from: message)
        try await db.collection(threadsCollection).document(threadId).setData([
            "lastMessageText": trimmed,
            "lastMessageAt": Timestamp(date: message.createdAt),
            "lastMessageBy": currentUid
        ], merge: true)
    }
    
    /// Attach a listener for messages in a thread. Call the returned cancel() to remove the listener.
    func listenToMessages(threadId: String, onUpdate: @escaping ([Message]) -> Void) -> () -> Void {
        let query = db.collection(threadsCollection).document(threadId).collection("messages")
            .order(by: "createdAt", descending: false)
        let listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                print("ThreadService listen error: \(error?.localizedDescription ?? "unknown")")
                return
            }
            let messages = snapshot.documents.compactMap { doc -> Message? in
                try? doc.data(as: Message.self)
            }
            Task { @MainActor in
                onUpdate(messages)
            }
        }
        return { listener.remove() }
    }
}
