//
//  CommunityPostDetailView.swift
//  SpotFinder
//
//  Post detail with a reply/comment section.
//

import SwiftUI

struct CommunityPostDetailView: View {
    let post: CommunityPost
    
    @StateObject private var communityService = CommunityService()
    @State private var comments: [CommunityComment] = []
    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var loadError: String?
    @State private var submitError: String?
    @State private var removeCommentsListener: (() -> Void)?
    
    var body: some View {
        ZStack {
            Image("PostsBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.28)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                postHeader
                
                if let loadError, comments.isEmpty {
                    bubbleStateCard(
                        title: "Could not load replies",
                        systemImage: "exclamationmark.triangle",
                        message: loadError
                    )
                } else if comments.isEmpty {
                    bubbleStateCard(
                        title: "No replies yet",
                        systemImage: "bubble.left.and.bubble.right",
                        message: "Be the first to reply."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(comments, id: \.id) { comment in
                                commentRow(comment)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                
                composerBar
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { startCommentsListener() }
        .onDisappear {
            removeCommentsListener?()
            removeCommentsListener = nil
        }
    }
    
    private var postHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.blue))
                
                NavigationLink(
                    destination: UserProfileView(
                        profile: UserProfile(uid: post.createdBy, username: post.createdByUsername)
                    )
                ) {
                    Text("@\(post.createdByUsername)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(post.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private func commentRow(_ comment: CommunityComment) -> some View {
        HStack {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    NavigationLink(
                        destination: UserProfileView(
                            profile: UserProfile(uid: comment.createdBy, username: comment.createdByUsername)
                        )
                    ) {
                        Text("@\(comment.createdByUsername)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(comment.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            Spacer(minLength: 0)
        }
    }
    
    private var composerBar: some View {
        HStack {
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                if let submitError {
                    Text(submitError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack(spacing: 10) {
                    TextField("Write a reply...", text: $commentText, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                        )
                    
                    Button(isSubmitting ? "..." : "Send") {
                        Task { await submitComment() }
                    }
                    .disabled(isSubmitting || commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }
    
    private func bubbleStateCard(title: String, systemImage: String, message: String) -> some View {
        HStack {
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 16)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
    }
    
    private func startCommentsListener() {
        removeCommentsListener?()
        guard let postId = post.id else {
            loadError = "Invalid post ID."
            return
        }
        removeCommentsListener = communityService.listenToComments(
            postId: postId,
            onUpdate: { updated in
                comments = updated
                loadError = nil
            },
            onError: { message in
                loadError = message
            }
        )
    }
    
    private func submitComment() async {
        guard let postId = post.id else {
            submitError = "Invalid post ID."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            try await communityService.createComment(postId: postId, text: commentText)
            commentText = ""
            submitError = nil
        } catch {
            submitError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationView {
        CommunityPostDetailView(
            post: CommunityPost(
                createdBy: "abc",
                createdByUsername: "skater123",
                text: "Anyone down for a session at 5 PM?"
            )
        )
    }
}

