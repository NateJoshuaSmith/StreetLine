//
//  UserService.swift
//  SpotFinder
//
//  Created for username display feature.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine

// MARK: - Friends list UI cache (in-memory for the app session)

/// Snapshot of resolved friends + pending rows for instant list display on repeat visits.
struct FriendsListDisplayCache: Sendable {
    let userId: String
    let friends: [UserProfile]
    let pendingSentProfiles: [UserProfile]
    let pendingReceived: [(FriendRequest, UserProfile)]
    let loadedAt: Date
}

extension UserService {
    private static let friendsListCacheLock = NSLock()
    private static var friendsListDisplayCache: FriendsListDisplayCache?
    
    /// Last cached friends UI for this user (same session). Cleared on logout.
    static func friendsListDisplayCache(forUserId uid: String) -> FriendsListDisplayCache? {
        friendsListCacheLock.lock()
        defer { friendsListCacheLock.unlock() }
        guard let c = friendsListDisplayCache, c.userId == uid else { return nil }
        return c
    }
    
    static func storeFriendsListDisplayCache(_ cache: FriendsListDisplayCache) {
        friendsListCacheLock.lock()
        defer { friendsListCacheLock.unlock() }
        friendsListDisplayCache = cache
    }
    
    static func clearFriendsListDisplayCache() {
        friendsListCacheLock.lock()
        defer { friendsListCacheLock.unlock() }
        friendsListDisplayCache = nil
    }
}

class UserService: ObservableObject {
    private let authService = AuthService()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let collectionName = "users"
    private let spotsCollectionName = "skateSpots"
    private let avatarPathPrefix = "avatars"
    
    /// Favorite spot IDs for the current user (loaded via loadFavorites())
    @Published var favoriteSpotIds: [String] = []
    
    /// Username rules: 3–20 characters, letters/numbers/underscore only
    static let usernameMinLength = 3
    static let usernameMaxLength = 20
    static let usernameAllowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    
    /// Create a new user profile (call after sign up)
    func createProfile(uid: String, username: String, email: String?) async throws {
        let profile = UserProfile(uid: uid, username: username, email: email)
        var data = (try? Firestore.Encoder().encode(profile)) ?? [:]
        data["usernameLowercase"] = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try await db.collection(collectionName).document(uid).setData(data)
    }
    
    /// Fetch user profile by UID
    func getProfile(uid: String, source: FirestoreSource = .default) async throws -> UserProfile? {
        let document = try await db.collection(collectionName).document(uid).getDocument(source: source)
        guard document.exists else { return nil }
        return try document.data(as: UserProfile.self)
    }
    
    /// Batch-fetch profiles by UID (Firestore `in` queries are capped at 10 IDs per query).
    /// Preserves order of `orderedUids` in the returned array (skips missing docs).
    func fetchProfiles(forUids orderedUids: [String]) async throws -> [UserProfile] {
        let unique = Array(Set(orderedUids)).filter { !$0.isEmpty }
        guard !unique.isEmpty else { return [] }
        let chunkSize = 10
        var idToProfile: [String: UserProfile] = [:]
        try await withThrowingTaskGroup(of: [UserProfile].self) { group in
            var start = 0
            while start < unique.count {
                let end = min(start + chunkSize, unique.count)
                let chunk = Array(unique[start..<end])
                group.addTask {
                    let snapshot = try await self.db.collection(self.collectionName)
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    return snapshot.documents.compactMap { doc in
                        try? doc.data(as: UserProfile.self)
                    }
                }
                start = end
            }
            for try await batch in group {
                for profile in batch {
                    idToProfile[profile.uid] = profile
                }
            }
        }
        return orderedUids.compactMap { idToProfile[$0] }
    }
    
    /// Get current user's username (convenience method). Uses server fetch to avoid stale cache.
    /// Reads the "username" field directly so we don't depend on full UserProfile decoding.
    func getCurrentUsername() async -> String? {
        guard let uid = authService.currentUserId else { return nil }
        let doc = try? await db.collection(collectionName).document(uid).getDocument(source: .default)
        guard let data = doc?.data(),
              let name = data["username"] as? String,
              !name.isEmpty else { return nil }
        return name
    }
    
    /// Get current user's avatar URL from Firestore.
    func getCurrentAvatarURL() async -> String? {
        guard let uid = authService.currentUserId else { return nil }
        let doc = try? await db.collection(collectionName).document(uid).getDocument(source: .default)
        guard let data = doc?.data(),
              let url = data["avatarURL"] as? String,
              !url.isEmpty else { return nil }
        return url
    }
    
    /// Upload avatar image to Storage and save URL to user document. Replaces any existing avatar.
    func uploadAvatar(data: Data) async throws -> String {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let path = "\(avatarPathPrefix)/\(uid).jpg"
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        let urlString = url.absoluteString
        try await db.collection(collectionName).document(uid).setData(["avatarURL": urlString], merge: true)
        return urlString
    }
    
    /// Validate username format (length and allowed characters). Returns nil if valid, or an error message.
    func validateUsername(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Username cannot be empty"
        }
        if trimmed.count < Self.usernameMinLength {
            return "Username must be at least \(Self.usernameMinLength) characters"
        }
        if trimmed.count > Self.usernameMaxLength {
            return "Username must be at most \(Self.usernameMaxLength) characters"
        }
        let allowed = Self.usernameAllowedCharacterSet
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Use only letters, numbers, and underscores"
        }
        return nil
    }
    
    /// Returns true if the username is available (no other user has it, or only the current user has it).
    /// Checks both usernameLowercase (case-insensitive) and exact username for backwards compatibility.
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLower = trimmed.lowercased()
        // Case-insensitive check (requires Firestore index on users.usernameLowercase)
        let byLower = try await db.collection(collectionName)
            .whereField("usernameLowercase", isEqualTo: trimmedLower)
            .limit(to: 2)
            .getDocuments()
        if let other = byLower.documents.first(where: { $0.documentID != uid }) { return false }
        if byLower.documents.isEmpty {
            // Fallback: exact match for legacy users without usernameLowercase
            let byExact = try await db.collection(collectionName)
                .whereField("username", isEqualTo: trimmed)
                .limit(to: 2)
                .getDocuments()
            if let other = byExact.documents.first(where: { $0.documentID != uid }) { return false }
        }
        return true
    }
    
    /// Update username for current user. Validates format and uniqueness, then updates Firestore and denormalized data.
    func updateUsername(_ newUsername: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let trimmed = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = validateUsername(trimmed) {
            throw NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: error])
        }
        let trimmedLower = trimmed.lowercased()
        guard try await isUsernameAvailable(trimmed) else {
            throw NSError(domain: "UserService", code: 409, userInfo: [NSLocalizedDescriptionKey: "That username is already taken"])
        }
        // Store display version and lowercase for uniqueness queries
        try await db.collection(collectionName).document(uid).setData([
            "username": trimmed,
            "usernameLowercase": trimmedLower
        ], merge: true)
        // Update denormalized createdByUsername on spots and comments so "by @username" stays correct
        try await updateDenormalizedUsername(uid: uid, newUsername: trimmed)
    }
    
    /// Update createdByUsername on all spots owned by this user so "by @username" stays correct.
    private func updateDenormalizedUsername(uid: String, newUsername: String) async throws {
        let spotsSnapshot = try await db.collection(spotsCollectionName)
            .whereField("createdBy", isEqualTo: uid)
            .getDocuments()
        guard !spotsSnapshot.documents.isEmpty else { return }
        let batch = db.batch()
        for doc in spotsSnapshot.documents {
            batch.updateData(["createdByUsername": newUsername], forDocument: doc.reference)
        }
        try await batch.commit()
    }
    
    /// Check if user has a profile (for existing users migrating to username system)
    func hasProfile(uid: String) async -> Bool {
        let document = try? await db.collection(collectionName).document(uid).getDocument()
        return document?.exists ?? false
    }
    
    // MARK: - Favorites
    
    /// Load favorite spot IDs from Firestore into favoriteSpotIds.
    func loadFavorites() async {
        guard let uid = authService.currentUserId else {
            await MainActor.run { favoriteSpotIds = [] }
            return
        }
        do {
            let doc = try await db.collection(collectionName).document(uid).getDocument()
            let ids = doc.data()?["favoriteSpotIds"] as? [String] ?? []
            await MainActor.run { favoriteSpotIds = ids }
        } catch {
            print("Error loading favorites: \(error)")
            await MainActor.run { favoriteSpotIds = [] }
        }
    }
    
    /// Add a spot to favorites (current user only).
    func addFavorite(spotId: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        try await db.collection(collectionName).document(uid).setData([
            "favoriteSpotIds": FieldValue.arrayUnion([spotId])
        ], merge: true)
        await MainActor.run {
            if !favoriteSpotIds.contains(spotId) {
                favoriteSpotIds.append(spotId)
            }
        }
    }
    
    /// Remove a spot from favorites (current user only).
    func removeFavorite(spotId: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        try await db.collection(collectionName).document(uid).setData([
            "favoriteSpotIds": FieldValue.arrayRemove([spotId])
        ], merge: true)
        await MainActor.run {
            favoriteSpotIds.removeAll { $0 == spotId }
        }
    }
    
    /// Returns true if the given spot ID is in the current user's favorites.
    func isFavorite(spotId: String) -> Bool {
        favoriteSpotIds.contains(spotId)
    }
    
    // MARK: - Friends
    
    /// Friend user IDs for the current user (loaded via loadFriends()).
    @Published var friendIds: [String] = []
    
    /// UIDs the current user has sent a pending friend request to (loaded via loadPendingSent()).
    @Published var pendingSentIds: [String] = []
    
    private let friendRequestsCollection = "friendRequests"
    
    /// Load friend IDs from Firestore into friendIds.
    func loadFriends() async {
        guard let uid = authService.currentUserId else {
            await MainActor.run { friendIds = [] }
            return
        }
        do {
            let doc = try await db.collection(collectionName).document(uid).getDocument()
            let ids = doc.data()?["friendIds"] as? [String] ?? []
            await MainActor.run { friendIds = ids }
        } catch {
            print("Error loading friends: \(error)")
            await MainActor.run { friendIds = [] }
        }
    }
    
    /// Add a user as a friend (by their UID).
    func addFriend(friendUid: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        guard friendUid != uid else {
            throw NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "You can't add yourself"])
        }
        try await db.collection(collectionName).document(uid).setData([
            "friendIds": FieldValue.arrayUnion([friendUid])
        ], merge: true)
        await MainActor.run {
            if !friendIds.contains(friendUid) {
                friendIds.append(friendUid)
            }
        }
    }
    
    /// Remove a user from friends.
    func removeFriend(friendUid: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        // Remove friend from the current user's friendIds
        try await db.collection(collectionName).document(uid).setData([
            "friendIds": FieldValue.arrayRemove([friendUid])
        ], merge: true)
        
        // Mark any existing friend request between these two users as no longer active
        let outgoingId = FriendRequest.requestId(from: uid, to: friendUid)
        let incomingId = FriendRequest.requestId(from: friendUid, to: uid)
        let requestsRef = db.collection(friendRequestsCollection)
        // Best-effort updates; ignore failures so a missing doc doesn't break removal
        try? await requestsRef.document(outgoingId).setData([
            "status": FriendRequest.statusDeclined
        ], merge: true)
        try? await requestsRef.document(incomingId).setData([
            "status": FriendRequest.statusDeclined
        ], merge: true)
        
        await MainActor.run {
            friendIds.removeAll { $0 == friendUid }
        }
    }
    
    /// Returns true if the given user ID is in the current user's friends list.
    func isFriend(uid: String) -> Bool {
        friendIds.contains(uid)
    }
    
    /// Returns true if the current user has a pending sent request to this UID.
    func hasPendingSentRequest(toUid: String) -> Bool {
        pendingSentIds.contains(toUid)
    }
    
    // MARK: - Friend requests (pending until accepted)
    
    /// Send a friend request to a user. They must accept before they appear in friendIds.
    func createFriendRequest(toUid: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        guard toUid != uid else {
            throw NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "You can't add yourself"])
        }
        let requestId = FriendRequest.requestId(from: uid, to: toUid)
        let ref = db.collection(friendRequestsCollection).document(requestId)
        let existing = try? await ref.getDocument()
        if let doc = existing, doc.exists, let data = doc.data(),
           let status = data["status"] as? String {
            if status == FriendRequest.statusPending {
                return
            }
            if status == FriendRequest.statusAccepted {
                // If Firestore still says "accepted" but the other user is no longer
                // in our in-memory friendIds (e.g. friendship was removed), allow
                // a fresh request; otherwise, treat as already friends.
                if friendIds.contains(toUid) {
                    throw NSError(domain: "UserService", code: 409, userInfo: [NSLocalizedDescriptionKey: "Already friends"])
                }
                // Fall through and overwrite with a new pending request below.
            }
        }
        try await ref.setData([
            "fromUid": uid,
            "toUid": toUid,
            "status": FriendRequest.statusPending,
            "createdAt": Timestamp(date: Date())
        ])
        await MainActor.run {
            if !pendingSentIds.contains(toUid) {
                pendingSentIds.append(toUid)
            }
        }
    }
    
    /// Cancel a pending friend request you sent.
    func cancelFriendRequest(toUid: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let requestId = FriendRequest.requestId(from: uid, to: toUid)
        try await db.collection(friendRequestsCollection).document(requestId).updateData([
            "status": FriendRequest.statusDeclined
        ])
        await MainActor.run { pendingSentIds.removeAll { $0 == toUid } }
    }
    
    /// Accept an incoming friend request. Adds sender to the current user's friendIds;
    /// the sender will add the receiver on their side via processAcceptedRequests().
    func acceptFriendRequest(fromUid: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let requestId = FriendRequest.requestId(from: fromUid, to: uid)
        let ref = db.collection(friendRequestsCollection).document(requestId)
        let doc = try await ref.getDocument()
        guard doc.exists, let data = doc.data(),
              (data["status"] as? String) == FriendRequest.statusPending,
              (data["fromUid"] as? String) == fromUid,
              (data["toUid"] as? String) == uid else {
            throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Request not found or already handled"])
        }
        try await ref.updateData(["status": FriendRequest.statusAccepted])
        // Only update the current user's document; Firestore rules allow this.
        try await db.collection(collectionName).document(uid).setData([
            "friendIds": FieldValue.arrayUnion([fromUid])
        ], merge: true)
        await MainActor.run {
            if !friendIds.contains(fromUid) { friendIds.append(fromUid) }
        }
    }
    
    /// Call after loadFriends: for requests you sent that were accepted, add the acceptor to your friendIds.
    func processAcceptedRequests() async {
        guard let uid = authService.currentUserId else { return }
        do {
            let snapshot = try await db.collection(friendRequestsCollection)
                .whereField("fromUid", isEqualTo: uid)
                .whereField("status", isEqualTo: FriendRequest.statusAccepted)
                .getDocuments()
            for doc in snapshot.documents {
                let data = doc.data()
                let fromUid = data["fromUid"] as? String ?? ""
                let toUid = data["toUid"] as? String ?? ""
                guard fromUid == uid else { continue }
                let otherUid = toUid
                if !friendIds.contains(otherUid) {
                    try? await db.collection(collectionName).document(uid).setData([
                        "friendIds": FieldValue.arrayUnion([otherUid])
                    ], merge: true)
                    await MainActor.run { friendIds.append(otherUid) }
                }
            }
        } catch {
            print("Error processing accepted requests: \(error)")
        }
    }
    
    /// Decline an incoming friend request.
    func declineFriendRequest(fromUid: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let requestId = FriendRequest.requestId(from: fromUid, to: uid)
        try await db.collection(friendRequestsCollection).document(requestId).updateData([
            "status": FriendRequest.statusDeclined
        ])
    }
    
    /// Load UIDs the current user has sent a pending request to. Updates pendingSentIds.
    func loadPendingSent() async {
        guard let uid = authService.currentUserId else {
            await MainActor.run { pendingSentIds = [] }
            return
        }
        do {
            let snapshot = try await db.collection(friendRequestsCollection)
                .whereField("fromUid", isEqualTo: uid)
                .whereField("status", isEqualTo: FriendRequest.statusPending)
                .getDocuments()
            let ids = snapshot.documents.compactMap { $0.data()["toUid"] as? String }
            await MainActor.run { pendingSentIds = ids }
        } catch {
            print("Error loading pending sent: \(error)")
            await MainActor.run { pendingSentIds = [] }
        }
    }
    
    /// Load incoming pending friend requests (to the current user).
    func loadPendingReceived() async throws -> [FriendRequest] {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        print("[UserService] loadPendingReceived for uid=\(uid)")
        let snapshot = try await db.collection(friendRequestsCollection)
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: FriendRequest.statusPending)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        let requests = snapshot.documents.compactMap { doc in
            try? doc.data(as: FriendRequest.self)
        }
        print("[UserService] loadPendingReceived found \(requests.count) pending requests")
        return requests
    }
    
    /// Search users by username prefix (case-insensitive). Excludes current user. Requires Firestore rule allowing read on users for authenticated users.
    func searchUsers(byUsernamePrefix query: String) async throws -> [UserProfile] {
        guard let currentUid = authService.currentUserId else {
            throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        let end = trimmed + "\u{f8ff}"
        let snapshot = try await db.collection(collectionName)
            .whereField("usernameLowercase", isGreaterThanOrEqualTo: trimmed)
            .whereField("usernameLowercase", isLessThanOrEqualTo: end)
            .limit(to: 20)
            .getDocuments()
        var profiles: [UserProfile] = []
        for doc in snapshot.documents {
            guard doc.documentID != currentUid else { continue }
            if let profile = try? doc.data(as: UserProfile.self) {
                profiles.append(profile)
            }
        }
        return profiles
    }
}
