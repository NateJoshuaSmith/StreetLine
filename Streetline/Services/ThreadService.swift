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
        if let doc, doc.exists {
            if var thread = try? doc.data(as: Thread.self) {
                thread.id = threadId
                return thread
            }
            return Thread(
                id: threadId,
                participantIds: [currentUid, friendUid].sorted()
            )
        }
        let newThread = Thread(
            id: threadId,
            participantIds: [currentUid, friendUid].sorted(),
            lastMessageText: nil,
            lastMessageAt: nil,
            lastMessageBy: nil,
            lastReadAt: [currentUid: Date()]
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
    
    /// Record that the current user has seen the latest messages in this thread.
    func markThreadAsRead(threadId: String) async {
        guard let currentUid = authService.currentUserId, !threadId.isEmpty else { return }
        let now = Timestamp(date: Date())
        do {
            try await db.collection("users").document(currentUid).setData([
                "threadLastReadAt.\(threadId)": now
            ], merge: true)
        } catch {
            print("ThreadService persist user read error: \(error)")
        }
        do {
            try await db.collection(threadsCollection).document(threadId).setData([
                "lastReadAt.\(currentUid)": now
            ], merge: true)
        } catch {
            print("ThreadService markThreadAsRead error: \(error)")
        }
    }
    
    /// Listen to all threads the current user is in. Call the returned cancel() to remove the listener.
    func listenToThreads(onUpdate: @escaping ([Thread]) -> Void) -> () -> Void {
        guard let currentUid = authService.currentUserId else {
            onUpdate([])
            return {}
        }
        let query = db.collection(threadsCollection)
            .whereField("participantIds", arrayContains: currentUid)
        let listener = query.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                print("ThreadService listenToThreads error: \(error?.localizedDescription ?? "unknown")")
                return
            }
            let threads = snapshot.documents.compactMap { Self.decodeThread(from: $0) }
            Task { @MainActor in
                onUpdate(threads)
            }
        }
        return { listener.remove() }
    }
    
    /// Codable can drop a thread if `lastReadAt` is a Timestamp map; parse those fields by hand.
    private static func decodeThread(from doc: QueryDocumentSnapshot) -> Thread? {
        if var thread = try? doc.data(as: Thread.self) {
            thread.id = doc.documentID
            return thread
        }
        let data = doc.data()
        guard let participantIds = data["participantIds"] as? [String] else {
            print("ThreadService skipped \(doc.documentID): missing participantIds")
            return nil
        }
        var lastReadAt: [String: Date] = [:]
        if let raw = data["lastReadAt"] as? [String: Any] {
            for (key, value) in raw {
                if let timestamp = value as? Timestamp {
                    lastReadAt[key] = timestamp.dateValue()
                } else if let date = value as? Date {
                    lastReadAt[key] = date
                }
            }
        }
        return Thread(
            id: doc.documentID,
            participantIds: participantIds,
            lastMessageText: data["lastMessageText"] as? String,
            lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue(),
            lastMessageBy: data["lastMessageBy"] as? String,
            lastReadAt: lastReadAt.isEmpty ? nil : lastReadAt
        )
    }
}
