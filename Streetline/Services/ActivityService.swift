//
//  ActivityService.swift
//  Streetline
//
//  Live unread message and incoming friend-request counts for badges.
//  Read state is stored on the user document so it survives logout.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class ActivityService: ObservableObject {
    @Published private(set) var pendingFriendRequestCount = 0
    @Published private(set) var unreadThreadCount = 0
    @Published private(set) var unreadFriendUids: Set<String> = []
    @Published private(set) var homeBadgeCount = 0
    
    private let db = Firestore.firestore()
    private var requestListener: ListenerRegistration?
    private var threadsListener: ListenerRegistration?
    private var userListener: ListenerRegistration?
    private var friendThreadListeners: [String: ListenerRegistration] = [:]
    private var threadsById: [String: Thread] = [:]
    /// threadId → last time this user opened that chat
    private var threadLastReadAt: [String: Date] = [:]
    private var currentUid: String?
    private var isListening = false
    
    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if isListening, currentUid == uid { return }
        stopListening()
        currentUid = uid
        isListening = true
        threadLastReadAt = Self.loadCachedReads(for: uid)
        listenForFriendRequests(uid: uid)
        listenForUserReadState(uid: uid)
        listenForThreads(uid: uid)
        applyThreads()
    }
    
    func stopListening() {
        requestListener?.remove()
        requestListener = nil
        threadsListener?.remove()
        threadsListener = nil
        userListener?.remove()
        userListener = nil
        friendThreadListeners.values.forEach { $0.remove() }
        friendThreadListeners.removeAll()
        threadsById.removeAll()
        threadLastReadAt.removeAll()
        currentUid = nil
        isListening = false
        pendingFriendRequestCount = 0
        unreadThreadCount = 0
        unreadFriendUids = []
        homeBadgeCount = 0
    }
    
    func hasUnreadMessages(fromFriendUid uid: String) -> Bool {
        unreadFriendUids.contains(uid)
    }
    
    /// Mark this chat read locally and persist so the dot stays gone after logout.
    func markConversationOpened(withFriendUid friendUid: String) {
        guard let uid = currentUid ?? Auth.auth().currentUser?.uid else { return }
        let threadId = Thread.threadId(between: uid, and: friendUid)
        let now = Date()
        threadLastReadAt[threadId] = now
        Self.storeCachedRead(threadId: threadId, at: now, for: uid)
        
        if var thread = threadsById[threadId] {
            var reads = thread.lastReadAt ?? [:]
            reads[uid] = now
            thread.lastReadAt = reads
            threadsById[threadId] = thread
        }
        applyThreads()
        
        Task {
            do {
                try await db.collection("users").document(uid).setData([
                    "threadLastReadAt.\(threadId)": Timestamp(date: now)
                ], merge: true)
            } catch {
                print("ActivityService persist read error: \(error)")
            }
            do {
                try await db.collection("threads").document(threadId).setData([
                    "lastReadAt.\(uid)": Timestamp(date: now)
                ], merge: true)
            } catch {
                print("ActivityService thread lastReadAt error: \(error)")
            }
        }
    }
    
    private func listenForUserReadState(uid: String) {
        userListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("ActivityService user listen error: \(error.localizedDescription)")
                return
            }
            var reads: [String: Date] = [:]
            if let raw = snapshot?.data()?["threadLastReadAt"] as? [String: Any] {
                for (threadId, value) in raw {
                    if let timestamp = value as? Timestamp {
                        reads[threadId] = timestamp.dateValue()
                    } else if let date = value as? Date {
                        reads[threadId] = date
                    }
                }
            }
            Task { @MainActor in
                guard let self else { return }
                for (threadId, date) in reads {
                    if let existing = self.threadLastReadAt[threadId] {
                        self.threadLastReadAt[threadId] = max(existing, date)
                    } else {
                        self.threadLastReadAt[threadId] = date
                    }
                }
                Self.storeCachedReads(self.threadLastReadAt, for: uid)
                self.applyThreads()
            }
        }
    }
    
    private func listenForFriendRequests(uid: String) {
        requestListener = db.collection("friendRequests")
            .whereField("toUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    print("ActivityService friend request listen error: \(error.localizedDescription)")
                    return
                }
                let count = snapshot?.documents.filter {
                    ($0.data()["status"] as? String) == FriendRequest.statusPending
                }.count ?? 0
                Task { @MainActor in
                    self?.pendingFriendRequestCount = count
                    self?.refreshHomeBadge()
                }
            }
    }
    
    private func listenForThreads(uid: String) {
        threadsListener = db.collection("threads")
            .whereField("participantIds", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    print("ActivityService threads listen error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self?.listenToFriendThreadDocuments(uid: uid)
                    }
                    return
                }
                Task { @MainActor in
                    guard let self else { return }
                    var next: [String: Thread] = [:]
                    for doc in snapshot?.documents ?? [] {
                        if let thread = Self.decodeThread(doc) {
                            next[doc.documentID] = thread
                        }
                    }
                    self.threadsById = next
                    self.applyThreads()
                }
            }
    }
    
    private func listenToFriendThreadDocuments(uid: String) {
        guard friendThreadListeners.isEmpty else { return }
        db.collection("users").document(uid).getDocument { [weak self] snapshot, _ in
            let friendIds = snapshot?.data()?["friendIds"] as? [String] ?? []
            Task { @MainActor in
                guard let self else { return }
                for friendId in friendIds {
                    let threadId = Thread.threadId(between: uid, and: friendId)
                    self.friendThreadListeners[threadId] = self.db.collection("threads").document(threadId).addSnapshotListener { snapshot, _ in
                        Task { @MainActor in
                            if let snapshot, snapshot.exists, let thread = Self.decodeThread(snapshot) {
                                self.threadsById[threadId] = thread
                            }
                            self.applyThreads()
                        }
                    }
                }
            }
        }
    }
    
    private func applyThreads() {
        guard let uid = currentUid ?? Auth.auth().currentUser?.uid else {
            unreadThreadCount = 0
            unreadFriendUids = []
            refreshHomeBadge()
            return
        }
        var friendUids = Set<String>()
        for thread in threadsById.values {
            guard let threadId = thread.id,
                  let lastMessageBy = thread.lastMessageBy,
                  lastMessageBy != uid,
                  let lastMessageAt = thread.lastMessageAt else {
                continue
            }
            let readAt = threadLastReadAt[threadId] ?? thread.lastReadAt?[uid]
            if let readAt, lastMessageAt <= readAt {
                continue
            }
            if let other = thread.otherParticipantId(currentUserId: uid) {
                friendUids.insert(other)
            }
        }
        unreadFriendUids = friendUids
        unreadThreadCount = friendUids.count
        refreshHomeBadge()
    }
    
    private func refreshHomeBadge() {
        homeBadgeCount = pendingFriendRequestCount + unreadThreadCount
    }
    
    private static func cacheKey(for uid: String) -> String {
        "threadLastReadAt.\(uid)"
    }
    
    private static func loadCachedReads(for uid: String) -> [String: Date] {
        guard let raw = UserDefaults.standard.dictionary(forKey: cacheKey(for: uid)) as? [String: Double] else {
            return [:]
        }
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }
    
    private static func storeCachedRead(threadId: String, at date: Date, for uid: String) {
        var raw = UserDefaults.standard.dictionary(forKey: cacheKey(for: uid)) as? [String: Double] ?? [:]
        raw[threadId] = date.timeIntervalSince1970
        UserDefaults.standard.set(raw, forKey: cacheKey(for: uid))
    }
    
    private static func storeCachedReads(_ reads: [String: Date], for uid: String) {
        let raw = reads.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: cacheKey(for: uid))
    }
    
    private static func decodeThread(_ snapshot: DocumentSnapshot) -> Thread? {
        let data = snapshot.data() ?? [:]
        guard let participantIds = data["participantIds"] as? [String] else {
            return try? snapshot.data(as: Thread.self)
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
            id: snapshot.documentID,
            participantIds: participantIds,
            lastMessageText: data["lastMessageText"] as? String,
            lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue(),
            lastMessageBy: data["lastMessageBy"] as? String,
            lastReadAt: lastReadAt.isEmpty ? nil : lastReadAt
        )
    }
}
