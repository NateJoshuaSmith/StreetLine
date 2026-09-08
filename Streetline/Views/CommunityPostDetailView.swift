//
//  CommunityPostDetailView.swift
//  SpotFinder
//
//  Post detail with a reply/comment section.
//

import SwiftUI
import FirebaseAuth

struct CommunityPostDetailView: View {
    let post: CommunityPost
    
    @StateObject private var communityService = CommunityService()
    @State private var comments: [CommunityComment] = []
    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var loadError: String?
    @State private var submitError: String?
    @State private var removeCommentsListener: (() -> Void)?
    @StateObject private var userService = UserService()
    @State private var showReportPost = false
    @State private var commentToReport: CommunityComment?
    @State private var userToBlock: (uid: String, username: String)?
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var visibleComments: [CommunityComment] {
        comments.filter { !UserService.isUserBlocked($0.createdBy) }
    }
    
    var body: some View {
        ZStack {
            ArtBackdrop(imageName: "PostsBackground", dim: 0.28)
            
            VStack(spacing: 12) {
                postHeader
                
                if let loadError, comments.isEmpty {
                    bubbleStateCard(
                        title: "Could not load replies",
                        systemImage: "exclamationmark.triangle",
                        message: loadError
                    )
                } else if visibleComments.isEmpty {
                    bubbleStateCard(
                        title: "No replies yet",
                        systemImage: "bubble.left.and.bubble.right",
                        message: "Be the first to reply."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(visibleComments, id: \.id) { comment in
                                commentRow(comment)
                                    .contextMenu {
                                        if comment.createdBy != currentUid {
                                            Button {
                                                commentToReport = comment
                                            } label: {
                                                Label("Report reply", systemImage: "flag")
                                            }
                                            Button(role: .destructive) {
                                                userToBlock = (comment.createdBy, comment.createdByUsername)
                                            } label: {
                                                Label("Block @\(comment.createdByUsername)", systemImage: "hand.raised")
                                            }
                                        }
                                    }
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
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if post.createdBy != currentUid {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showReportPost = true
                        } label: {
                            Label("Report post", systemImage: "flag")
                        }
                        Button(role: .destructive) {
                            userToBlock = (post.createdBy, post.createdByUsername)
                        } label: {
                            Label("Block @\(post.createdByUsername)", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await userService.loadBlockedUsers()
            startCommentsListener()
        }
        .sheet(isPresented: $showReportPost) {
            ReportContentView(
                title: "Report Post",
                prompt: "Why are you reporting this post?",
                type: .communityPost,
                targetId: post.id ?? "",
                targetPreview: post.text,
                reportedUserId: post.createdBy,
                onDismiss: { showReportPost = false }
            )
        }
        .sheet(isPresented: Binding(
            get: { commentToReport != nil },
            set: { if !$0 { commentToReport = nil } }
        )) {
            if let comment = commentToReport {
                ReportContentView(
                    title: "Report Reply",
                    prompt: "Why are you reporting this reply?",
                    type: .communityComment,
                    targetId: comment.id ?? "",
                    targetPreview: comment.text,
                    reportedUserId: comment.createdBy,
                    onDismiss: { commentToReport = nil }
                )
            }
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: Binding(
                get: { userToBlock != nil },
                set: { if !$0 { userToBlock = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let user = userToBlock {
                    Task {
                        try? await userService.blockUser(user.uid)
                        comments = comments.filter { !UserService.isUserBlocked($0.createdBy) }
                    }
                }
                userToBlock = nil
            }
            Button("Cancel", role: .cancel) { userToBlock = nil }
        } message: {
            if let user = userToBlock {
                Text("You won't see posts or comments from @\(user.username).")
            }
        }
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
            }
            
            SessionPostMeta(post: post)
            
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
        EmptyStateCard(title: title, systemImage: systemImage, message: message)
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

