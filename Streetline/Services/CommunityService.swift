//
//  CommunityService.swift
//  SpotFinder
//
//  Manages forum-style community posts.
//

import Foundation
import Combine
import FirebaseFirestore

class CommunityService: ObservableObject {
    private let authService = AuthService()
    private let userService = UserService()
    private let db = Firestore.firestore()
    private let collectionName = "communityPosts"
    
    /// Create a new post in the community forum.
    func createPost(text: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "CommunityService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let username = await userService.getCurrentUsername() ?? "Unknown"
        let post = CommunityPost(
            createdBy: uid,
            createdByUsername: username,
            text: trimmed,
            createdAt: Date()
        )
        let ref = db.collection(collectionName).document()
        try await ref.setData(from: post)
    }
    
    /// Listen to recent forum posts. Caller should invoke returned closure to stop listening.
    func listenToPosts(
        onUpdate: @escaping ([CommunityPost]) -> Void,
        onError: @escaping (String) -> Void
    ) -> () -> Void {
        let query = db.collection(collectionName)
            .order(by: "createdAt", descending: true)
        
        let listener = query.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                let message = error?.localizedDescription ?? "unknown"
                print("CommunityService listen error: \(message)")
                Task { @MainActor in
                    onError(message)
                }
                return
            }
            let posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            Task { @MainActor in
                onUpdate(posts)
            }
        }
        
        return { listener.remove() }
    }
    
    /// Fetch all community posts created by one user, newest first.
    func fetchPosts(createdBy uid: String) async throws -> [CommunityPost] {
        let snapshot = try await db.collection(collectionName)
            .whereField("createdBy", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
    }
    
    /// Create a reply on a specific community post.
    func createComment(postId: String, text: String) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "CommunityService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let username = await userService.getCurrentUsername() ?? "Unknown"
        let comment = CommunityComment(
            createdBy: uid,
            createdByUsername: username,
            text: trimmed,
            createdAt: Date()
        )
        let ref = db.collection(collectionName)
            .document(postId)
            .collection("comments")
            .document()
        try await ref.setData(from: comment)
    }
    
    /// Listen to replies on a specific post.
    func listenToComments(
        postId: String,
        onUpdate: @escaping ([CommunityComment]) -> Void,
        onError: @escaping (String) -> Void
    ) -> () -> Void {
        let query = db.collection(collectionName)
            .document(postId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
        
        let listener = query.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                let message = error?.localizedDescription ?? "unknown"
                print("CommunityService comments listen error: \(message)")
                Task { @MainActor in
                    onError(message)
                }
                return
            }
            let comments = snapshot.documents.compactMap { try? $0.data(as: CommunityComment.self) }
            Task { @MainActor in
                onUpdate(comments)
            }
        }
        
        return { listener.remove() }
    }
}

