//
//  UserProfileView.swift
//  SpotFinder
//
//  Simple profile page for a SpotFinder user.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserProfileView: View {
    let profile: UserProfile
    
    @StateObject private var userService = UserService()
    @StateObject private var spotService = SpotService()
    @StateObject private var communityService = CommunityService()
    @State private var loadedProfile: UserProfile?
    @State private var userSpots: [SkateSpot] = []
    @State private var userCommunityPosts: [CommunityPost] = []
    @State private var isLoadingProfile = true
    @State private var profileLoadError: String?
    @State private var isSendingRequest = false
    @State private var requestError: String?
    @State private var showReportUser = false
    @State private var showBlockConfirm = false
    @State private var safetyError: String?
    
    private var displayProfile: UserProfile {
        loadedProfile ?? profile
    }
    
    private var isCurrentUser: Bool {
        Auth.auth().currentUser?.uid == displayProfile.uid
    }
    
    private var isFriend: Bool {
        userService.isFriend(uid: displayProfile.uid)
    }
    
    private var isBlocked: Bool {
        userService.isBlocked(uid: displayProfile.uid)
    }
    
    private var hasPendingSent: Bool {
        userService.hasPendingSentRequest(toUid: displayProfile.uid)
    }
    
    private var formattedJoinDate: String? {
        guard let createdAt = displayProfile.createdAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar
                avatarView
                    .padding(.top, 24)
                
                // Username + basic info
                VStack(spacing: 8) {
                    Text(displayProfile.username)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if let email = displayProfile.email, !email.isEmpty, isCurrentUser {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let join = formattedJoinDate {
                        Text("Member since \(join)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    if isCurrentUser {
                        Text("This is your profile")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                    
                    if displayProfile.hasSkateDetails {
                        skateDetailsCard
                    } else if isCurrentUser {
                        Text("Add age, skill, and favorites in Settings → Skate profile")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)
                
                if isLoadingProfile {
                    ProgressView("Loading profile...")
                } else if let profileLoadError {
                    Text(profileLoadError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                if !isCurrentUser {
                    VStack(spacing: 12) {
                        if isBlocked {
                            Text("You blocked this user. Their posts, comments, and messages are hidden.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            NavigationLink(destination: ConversationView(friendProfile: displayProfile)) {
                                Label("Message", systemImage: "bubble.left.and.bubble.right.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                Task { await sendFriendRequest() }
                            } label: {
                                if isFriend {
                                    Label("Already friends", systemImage: "checkmark.circle.fill")
                                } else if hasPendingSent {
                                    Label("Request sent", systemImage: "clock.fill")
                                } else if isSendingRequest {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Label("Add friend", systemImage: "person.badge.plus")
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                (isFriend || hasPendingSent || isSendingRequest) ? Color.gray : Color.green
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(isFriend || hasPendingSent || isSendingRequest)
                        }
                        
                        Button {
                            showReportUser = true
                        } label: {
                            Label("Report", systemImage: "flag")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(role: .destructive) {
                            if isBlocked {
                                Task { await unblockUser() }
                            } else {
                                showBlockConfirm = true
                            }
                        } label: {
                            Label(isBlocked ? "Unblock" : "Block", systemImage: isBlocked ? "hand.raised.slash" : "hand.raised")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        
                        if let error = requestError ?? safetyError {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                        
                        if !isBlocked {
                            Text("You can start a conversation or manage friendship from the Friends screen.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    contentHeader(title: "Skate With (\(userCommunityPosts.count))")
                    if userCommunityPosts.isEmpty {
                        emptyBubble(text: "No sessions yet.")
                    } else {
                        ForEach(userCommunityPosts.prefix(8), id: \.id) { post in
                            communityPostRow(post)
                        }
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 12) {
                    contentHeader(title: "Spots Added (\(userSpots.count))")
                    if userSpots.isEmpty {
                        emptyBubble(text: "No skate spots added yet.")
                    } else {
                        ForEach(userSpots.prefix(8), id: \.id) { spot in
                            spotRow(spot)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 0)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await userService.loadFriends()
            await userService.loadPendingSent()
            await userService.loadBlockedUsers()
            await loadProfileContent()
        }
        .sheet(isPresented: $showReportUser) {
            ReportContentView(
                title: "Report User",
                prompt: "Why are you reporting this account?",
                type: .user,
                targetId: displayProfile.uid,
                targetPreview: displayProfile.username,
                reportedUserId: displayProfile.uid,
                onDismiss: { showReportUser = false }
            )
        }
        .confirmationDialog(
            "Block @\(displayProfile.username)?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task { await blockUser() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("They won't be able to message you, and you won't see their posts or comments.")
        }
    }
    
    private var skateDetailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let age = displayProfile.age {
                detailRow(title: "Age", value: "\(age)")
            }
            if let skill = displayProfile.skillLevel, !skill.isEmpty {
                detailRow(title: "Skill", value: skill)
            }
            if let trick = displayProfile.favoriteTrick, !trick.isEmpty {
                detailRow(title: "Favorite trick", value: trick)
            }
            if let skater = displayProfile.favoriteSkater, !skater.isEmpty {
                detailRow(title: "Favorite skater", value: skater)
            }
        }
        .padding(14)
        .frame(maxWidth: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let urlString = displayProfile.avatarURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    avatarPlaceholder
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .shadow(radius: 6)
        } else {
            avatarPlaceholder
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .shadow(radius: 6)
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.title)
            )
    }
    
    private func contentHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
    }
    
    private func emptyBubble(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.body.weight(.bold))
                .foregroundColor(.black)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.black)
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black, lineWidth: 2)
        )
    }
    
    private func communityPostRow(_ post: CommunityPost) -> some View {
        NavigationLink(destination: CommunityPostDetailView(post: post)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(post.formattedWhen)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                if let whereText = post.displayWhere {
                    Text(whereText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if !post.text.isEmpty {
                    Text(post.text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func spotRow(_ spot: SkateSpot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(spot.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            Text(spot.comment)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text(spot.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
        )
    }
}

extension UserProfileView {
    private func loadProfileContent() async {
        await MainActor.run {
            isLoadingProfile = true
            profileLoadError = nil
        }
        
        async let freshProfile = userService.getProfile(uid: profile.uid, source: .default)
        async let spots = spotService.fetchSpots(createdBy: profile.uid)
        async let communityPosts = try? communityService.fetchPosts(createdBy: profile.uid)
        
        do {
            let resolvedProfile = try await freshProfile
            let resolvedSpots = await spots
            let resolvedPosts = await communityPosts ?? []
            
            await MainActor.run {
                loadedProfile = resolvedProfile ?? profile
                userSpots = resolvedSpots
                userCommunityPosts = resolvedPosts
                isLoadingProfile = false
            }
        } catch {
            let resolvedSpots = await spots
            let resolvedPosts = await communityPosts ?? []
            await MainActor.run {
                loadedProfile = profile
                userSpots = resolvedSpots
                userCommunityPosts = resolvedPosts
                profileLoadError = error.localizedDescription
                isLoadingProfile = false
            }
        }
    }
    
    private func sendFriendRequest() async {
        guard !isFriend, !hasPendingSent, !isSendingRequest else { return }
        await MainActor.run {
            isSendingRequest = true
            requestError = nil
        }
        do {
            try await userService.createFriendRequest(toUid: displayProfile.uid)
            await userService.loadPendingSent()
        } catch {
            await MainActor.run {
                requestError = (error as NSError).localizedDescription
            }
        }
        await MainActor.run {
            isSendingRequest = false
        }
    }
    
    private func blockUser() async {
        do {
            try await userService.blockUser(displayProfile.uid)
            await MainActor.run { safetyError = nil }
        } catch {
            await MainActor.run { safetyError = error.localizedDescription }
        }
    }
    
    private func unblockUser() async {
        do {
            try await userService.unblockUser(displayProfile.uid)
            await MainActor.run { safetyError = nil }
        } catch {
            await MainActor.run { safetyError = error.localizedDescription }
        }
    }
}

