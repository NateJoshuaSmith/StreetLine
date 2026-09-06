//
//  CommunityForumView.swift
//  SpotFinder
//
//  Community page for posting "looking to skate" messages.
//

import SwiftUI

struct CommunityForumView: View {
    @StateObject private var communityService = CommunityService()
    @State private var posts: [CommunityPost] = []
    @State private var isShowingComposer = false
    @State private var newPostText = ""
    @State private var isSubmitting = false
    @State private var loadError: String?
    @State private var submitError: String?
    @State private var removeListener: (() -> Void)?
    
    var body: some View {
        ZStack {
            Image("PostsBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.28)
                .ignoresSafeArea()
            
            content
                .padding(.horizontal)
                .padding(.top, 10)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Community")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.95)))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingComposer = true
                } label: {
                    Image(systemName: "plus.bubble.fill")
                }
            }
        }
        .sheet(isPresented: $isShowingComposer) {
            composerSheet
        }
        .task {
            startListening()
        }
        .onDisappear {
            removeListener?()
            removeListener = nil
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if let loadError, posts.isEmpty {
            bubbleStateCard(
                title: "Could not load community posts",
                systemImage: "exclamationmark.triangle",
                message: loadError
            )
        } else if posts.isEmpty {
            bubbleStateCard(
                title: "No posts yet",
                systemImage: "person.3.sequence.fill",
                message: "Tap the + button to post that you're looking for someone to skate."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(posts, id: \.id) { post in
                        NavigationLink(destination: CommunityPostDetailView(post: post)) {
                            postCard(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    private func postCard(_ post: CommunityPost) -> some View {
        HStack {
            Spacer(minLength: 0)
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
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    Spacer()
                    Label("View replies", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(14)
            .frame(maxWidth: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            Spacer(minLength: 0)
        }
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
    }
    
    private var composerSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Looking to skate?")
                    .font(.headline)
                
                Text("Post your plan so nearby skaters can join.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $newPostText)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                
                if let submitError {
                    Text(submitError)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isShowingComposer = false
                        newPostText = ""
                        submitError = nil
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSubmitting ? "Posting..." : "Post") {
                        Task { await submitPost() }
                    }
                    .disabled(isSubmitting || newPostText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func startListening() {
        removeListener?()
        removeListener = communityService.listenToPosts(
            onUpdate: { updatedPosts in
                posts = updatedPosts
                loadError = nil
            },
            onError: { message in
                loadError = message
            }
        )
    }
    
    private func submitPost() async {
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            try await communityService.createPost(text: newPostText)
            newPostText = ""
            submitError = nil
            isShowingComposer = false
        } catch {
            submitError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationView {
        CommunityForumView()
    }
}

