//
//  CommentService.swift
//  SpotFinder
//
//  Manages comments on skate spots with like/dislike support.
//

import Foundation
import Combine
import FirebaseFirestore

class CommentService: ObservableObject {
    private let db = Firestore.firestore()
    private let authService = AuthService()
    private let userService = UserService()
    
    @Published var comments: [SpotComment] = []
    private var listener: ListenerRegistration?
    
    private func commentsRef(spotId: String) -> CollectionReference {
        db.collection("skateSpots").document(spotId).collection("comments")
    }
    
    /// Listen for real-time comment updates on a spot
    func listenToComments(spotId: String) {
        listener?.remove()
        
        listener = commentsRef(spotId: spotId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error listening to comments: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                self?.comments = documents.compactMap { document in
                    try? document.data(as: SpotComment.self)
                }
            }
    }
    
    /// Stop listening when leaving the spot detail
    func stopListening() {
        listener?.remove()
        listener = nil
        comments = []
    }
    
    /// Add a comment to a spot
    func addComment(spotId: String, text: String) async throws {
        guard let userId = authService.currentUserId else {
            throw NSError(domain: "CommentService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Try profile username first, fallback to email prefix if profile missing or decode fails
        var username = await userService.getCurrentUsername()
        if username == nil || username?.isEmpty == true {
            if let email = authService.currentUserEmail {
                username = email.components(separatedBy: "@").first
            }
        }
        
        let comment = SpotComment(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            createdBy: userId,
            createdByUsername: username
        )
        
        _ = try commentsRef(spotId: spotId).addDocument(from: comment)
    }
    
    /// Toggle like on a comment (removes dislike if present)
    func toggleLike(spotId: String, comment: SpotComment) async throws {
        guard let commentId = comment.id, let userId = authService.currentUserId else { return }
        
        var likedBy = comment.likedBy
        var dislikedBy = comment.dislikedBy
        
        if likedBy.contains(userId) {
            likedBy.removeAll { $0 == userId }
        } else {
            likedBy.append(userId)
            dislikedBy.removeAll { $0 == userId }
        }
        
        try await commentsRef(spotId: spotId).document(commentId).updateData([
            "likedBy": likedBy,
            "dislikedBy": dislikedBy
        ])
    }
    
    /// Toggle dislike on a comment (removes like if present)
    func toggleDislike(spotId: String, comment: SpotComment) async throws {
        guard let commentId = comment.id, let userId = authService.currentUserId else { return }
        
        var likedBy = comment.likedBy
        var dislikedBy = comment.dislikedBy
        
        if dislikedBy.contains(userId) {
            dislikedBy.removeAll { $0 == userId }
        } else {
            dislikedBy.append(userId)
            likedBy.removeAll { $0 == userId }
        }
        
        try await commentsRef(spotId: spotId).document(commentId).updateData([
            "likedBy": likedBy,
            "dislikedBy": dislikedBy
        ])
    }
}
