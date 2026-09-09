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
    
    private let actionBlue = Color(red: 0.08, green: 0.32, blue: 0.78)
    private let actionGreen = Color(red: 0.12, green: 0.62, blue: 0.38)
    private let inkMuted = Color.black.opacity(0.72)
    
    var body: some View {
        ZStack {
            ArtBackdrop(imageName: "FriendsBackground", dim: 0.42, starBand: .header)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    identityCard
                    
                    if isLoadingProfile {
                        profileCard {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(.black)
                                Text("Loading profile...")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else if let profileLoadError {
                        Text(profileLoadError)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.red)
                    }
                    
                    if !isCurrentUser {
                        actionsCard
                    }
                    
                    profileCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("SKATE WITH (\(userCommunityPosts.count))")
                            if userCommunityPosts.isEmpty {
                                emptyLine("No sessions yet.")
                            } else {
                                ForEach(userCommunityPosts.prefix(8), id: \.id) { post in
                                    communityPostRow(post)
                                }
                            }
                        }
                    }
                    
                    profileCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("SPOTS ADDED (\(userSpots.count))")
                            if userSpots.isEmpty {
                                emptyLine("No skate spots added yet.")
                            } else {
                                ForEach(userSpots.prefix(8), id: \.id) { spot in
                                    spotRow(spot)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(displayProfile.username.isEmpty ? "Profile" : displayProfile.username)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color.white)
                            Capsule().strokeBorder(Color.black, lineWidth: 2.5)
                        }
                    )
            }
        }
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
    
    private func profileCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: 400, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black, lineWidth: 2.5)
            )
            .frame(maxWidth: .infinity)
    }
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.heavy))
            .tracking(0.6)
            .foregroundColor(.black)
    }
    
    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(inkMuted)
    }
    
    private func stickerButton(title: String, systemImage: String, fill: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.heavy))
            Text(title)
                .font(.subheadline.weight(.heavy))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black, lineWidth: 2.5)
        )
    }
    
    private var identityCard: some View {
        profileCard {
            VStack(spacing: 12) {
                avatarView
                
                Text(displayProfile.username)
                    .font(.title3.weight(.heavy))
                    .tracking(0.4)
                    .foregroundColor(.black)
                
                if let email = displayProfile.email, !email.isEmpty, isCurrentUser {
                    Text(email)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(inkMuted)
                }
                
                if let join = formattedJoinDate {
                    Text("Member since \(join)")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(inkMuted)
                }
                
                if isCurrentUser {
                    Text("This is your profile")
                        .font(.footnote.weight(.heavy))
                        .foregroundColor(.black)
                }
                
                if displayProfile.hasSkateDetails {
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
                    .padding(.top, 4)
                } else if isCurrentUser {
                    Text("Add age, skill, and favorites in Settings → Skate profile")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(inkMuted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var actionsCard: some View {
        profileCard {
            VStack(spacing: 10) {
                if isBlocked {
                    Text("You blocked this user. Their posts, comments, and messages are hidden.")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                } else {
                    NavigationLink(destination: ConversationView(friendProfile: displayProfile)) {
                        stickerButton(title: "MESSAGE", systemImage: "bubble.left.and.bubble.right.fill", fill: actionBlue)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        Task { await sendFriendRequest() }
                    } label: {
                        if isSendingRequest {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.black, lineWidth: 2.5)
                                )
                        } else if isFriend {
                            stickerButton(title: "ALREADY FRIENDS", systemImage: "checkmark.circle.fill", fill: Color.gray)
                        } else if hasPendingSent {
                            stickerButton(title: "REQUEST SENT", systemImage: "clock.fill", fill: Color.gray)
                        } else {
                            stickerButton(title: "ADD FRIEND", systemImage: "person.badge.plus", fill: actionGreen)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isFriend || hasPendingSent || isSendingRequest)
                }
                
                Button {
                    showReportUser = true
                } label: {
                    stickerButton(title: "REPORT", systemImage: "flag", fill: Color(red: 0.95, green: 0.55, blue: 0.12))
                }
                .buttonStyle(.plain)
                
                Button {
                    if isBlocked {
                        Task { await unblockUser() }
                    } else {
                        showBlockConfirm = true
                    }
                } label: {
                    stickerButton(
                        title: isBlocked ? "UNBLOCK" : "BLOCK",
                        systemImage: isBlocked ? "hand.raised.slash" : "hand.raised",
                        fill: Color.red
                    )
                }
                .buttonStyle(.plain)
                
                if let error = requestError ?? safetyError {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundColor(inkMuted)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.black)
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
            .overlay(Circle().stroke(Color.black, lineWidth: 2.5))
        } else {
            avatarPlaceholder
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 2.5))
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(actionBlue)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.title.weight(.heavy))
            )
    }
    
    private func communityPostRow(_ post: CommunityPost) -> some View {
        NavigationLink(destination: CommunityPostDetailView(post: post)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(post.formattedWhen)
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.black)
                if let whereText = post.displayWhere {
                    Text(whereText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(inkMuted)
                        .lineLimit(1)
                }
                if !post.text.isEmpty {
                    Text(post.text)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.black)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func spotRow(_ spot: SkateSpot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(spot.name)
                .font(.subheadline.weight(.heavy))
                .foregroundColor(.black)
            let comment = spot.comment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !comment.isEmpty, comment.caseInsensitiveCompare("No comment") != .orderedSame {
                Text(comment)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(inkMuted)
                    .lineLimit(2)
            }
            Text(spot.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption.weight(.semibold))
                .foregroundColor(inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

