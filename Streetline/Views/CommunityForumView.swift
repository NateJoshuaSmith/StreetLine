//
//  CommunityForumView.swift
//  SpotFinder
//
//  Community page for posting "looking to skate" messages.
//

import SwiftUI
import FirebaseAuth

struct CommunityForumView: View {
    @StateObject private var communityService = CommunityService()
    @State private var posts: [CommunityPost] = []
    @State private var isShowingComposer = false
    @State private var loadError: String?
    @State private var removeListener: (() -> Void)?
    @State private var postToReport: CommunityPost?
    @State private var userToBlock: (uid: String, username: String)?
    @StateObject private var userService = UserService()
    
    private var visiblePosts: [CommunityPost] {
        posts
            .filter { !$0.isExpired && !UserService.isUserBlocked($0.createdBy) }
            .sorted { $0.displayWhen < $1.displayWhen }
    }
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
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
                Text("Skate With")
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
            SkateWithComposerView { text, sessionAt, sessionWhat, spot, locationText in
                try await communityService.createPost(
                    text: text,
                    sessionAt: sessionAt,
                    sessionWhat: sessionWhat,
                    spot: spot,
                    locationText: locationText
                )
            }
        }
        .task {
            await userService.loadBlockedUsers()
            startListening()
        }
        .sheet(isPresented: Binding(
            get: { postToReport != nil },
            set: { if !$0 { postToReport = nil } }
        )) {
            if let post = postToReport {
                ReportContentView(
                    title: "Report Post",
                    prompt: "Why are you reporting this post?",
                    type: .communityPost,
                    targetId: post.id ?? "",
                    targetPreview: post.text,
                    reportedUserId: post.createdBy,
                    onDismiss: { postToReport = nil }
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
                        posts = posts.filter { !UserService.isUserBlocked($0.createdBy) }
                    }
                }
                userToBlock = nil
            }
            Button("Cancel", role: .cancel) {
                userToBlock = nil
            }
        } message: {
            if let user = userToBlock {
                Text("You won't see posts or comments from @\(user.username).")
            }
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
        } else if visiblePosts.isEmpty {
            bubbleStateCard(
                title: "No one's looking yet",
                systemImage: "person.3.sequence.fill",
                message: "Tap the + button to post when and where you're skating."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(visiblePosts, id: \.id) { post in
                        NavigationLink(destination: CommunityPostDetailView(post: post)) {
                            postCard(post)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if post.createdBy != currentUid {
                                Button {
                                    postToReport = post
                                } label: {
                                    Label("Report post", systemImage: "flag")
                                }
                                Button(role: .destructive) {
                                    userToBlock = (post.createdBy, post.createdByUsername)
                                } label: {
                                    Label("Block @\(post.createdByUsername)", systemImage: "hand.raised")
                                }
                            }
                        }
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
                }
                
                SessionPostMeta(post: post)
                
                if !post.text.isEmpty {
                    Text(post.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
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
        EmptyStateCard(title: title, systemImage: systemImage, message: message)
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
}

struct SessionPostMeta: View {
    let post: CommunityPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(post.formattedWhen, systemImage: "clock")
            if let whereText = post.displayWhere {
                Label(whereText, systemImage: "mappin.and.ellipse")
            }
            if let what = post.sessionWhat, !what.isEmpty {
                Text(what)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.12)))
            }
        }
        .font(.subheadline)
        .foregroundColor(.primary)
    }
}

struct SkateWithComposerView: View {
    var onSubmit: (String, Date, String, SkateSpot?, String?) async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotService = SpotService()
    @State private var sessionAt = SkateWithComposerView.defaultSessionTime()
    @State private var sessionWhat = "Street"
    @State private var selectedSpotId: String?
    @State private var locationText = ""
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    
    private var selectedSpot: SkateSpot? {
        spotService.spots.first { $0.id == selectedSpotId }
    }
    
    private var canPost: Bool {
        let hasPlace = selectedSpot != nil || !locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !sessionWhat.isEmpty && hasPlace && !isSubmitting
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("When") {
                    DatePicker(
                        "Session time",
                        selection: $sessionAt,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Text("This hides 24 hours after the session time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Where") {
                    Picker("Spot", selection: $selectedSpotId) {
                        Text("Type a place instead").tag(Optional<String>.none)
                        ForEach(spotService.spots) { spot in
                            Text(spot.name).tag(spot.id)
                        }
                    }
                    if selectedSpotId == nil {
                        TextField("Place name", text: $locationText)
                    }
                }
                
                Section("What") {
                    Picker("Type", selection: $sessionWhat) {
                        ForEach(CommunityPost.sessionTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Details (optional)") {
                    TextEditor(text: $details)
                        .frame(minHeight: 80)
                }
                
                if let submitError {
                    Section {
                        Text(submitError)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSubmitting ? "Posting..." : "Post") {
                        Task { await submit() }
                    }
                    .disabled(!canPost)
                }
            }
            .task {
                await spotService.fetchSpots()
            }
        }
    }
    
    private func submit() async {
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        do {
            try await onSubmit(details, sessionAt, sessionWhat, selectedSpot, locationText)
            dismiss()
        } catch {
            submitError = error.localizedDescription
        }
    }
    
    private static func defaultSessionTime() -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
    }
}

#Preview {
    NavigationView {
        CommunityForumView()
    }
}

