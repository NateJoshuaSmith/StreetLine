//
//  FriendsListView.swift
//  SpotFinder
//
//  List of the current user's friends; search and add by username.
//

import SwiftUI
import FirebaseAuth

struct FriendsListView: View {
    @EnvironmentObject var activityService: ActivityService
    @StateObject private var userService = UserService()
    @State private var friends: [UserProfile] = []
    @State private var pendingSentProfiles: [UserProfile] = []
    @State private var pendingReceived: [(FriendRequest, UserProfile)] = []
    @State private var isLoading = true
    @State private var showAddFriend = false
    @State private var profileToOpen: UserProfile?
    
    private var isLoggedIn: Bool {
        Auth.auth().currentUser != nil
    }
    
    private var hasAnyContent: Bool {
        !friends.isEmpty || !pendingSentProfiles.isEmpty || !pendingReceived.isEmpty
    }
    
    var body: some View {
        ZStack {
            ArtBackdrop(imageName: "FriendsBackground", dim: 0.45)
            
            Group {
                if !isLoggedIn {
                    EmptyStateCard(
                        title: "Sign in to see friends",
                        systemImage: "person.2.slash",
                        message: "Log in to add and view your friends list."
                    )
                } else if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.black)
                        Text("Loading friends...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black, lineWidth: 2.5)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasAnyContent {
                    EmptyStateCard(
                        title: "No friends yet",
                        systemImage: "person.2.fill",
                        message: "Tap Add friend to search by username and add people."
                    )
                } else {
                    List {
                        if !pendingReceived.isEmpty {
                            Section("Requests (\(pendingReceived.count))") {
                                ForEach(pendingReceived, id: \.0.fromUid) { request, profile in
                                    HStack {
                                        Spacer(minLength: 0)
                                        
                                        HStack(spacing: 10) {
                                            profileButton(for: profile)
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 8, height: 8)
                                            Spacer(minLength: 8)
                                            Button("Accept") {
                                                Task { await acceptRequest(request.fromUid) }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                            Button("Decline", role: .destructive) {
                                                Task { await declineRequest(request.fromUid) }
                                            }
                                            .controlSize(.small)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.95))
                                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                                        )
                                        .frame(maxWidth: 360)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                }
                            }
                        }
                        if !friends.isEmpty {
                            Section("Friends") {
                                ForEach(friends, id: \.uid) { profile in
                                    HStack {
                                        Spacer(minLength: 0)
                                        
                                        HStack(spacing: 10) {
                                            profileButton(for: profile)
                                            
                                            Spacer(minLength: 8)
                                            
                                            NavigationLink(destination: ConversationView(friendProfile: profile)) {
                                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.body)
                                                    .overlay(alignment: .topTrailing) {
                                                        if activityService.hasUnreadMessages(fromFriendUid: profile.uid) {
                                                            Circle()
                                                                .fill(Color.red)
                                                                .frame(width: 8, height: 8)
                                                                .offset(x: 4, y: -4)
                                                        }
                                                    }
                                            }
                                            .buttonStyle(.plain)
                                            .navigationLinkIndicatorVisibility(.hidden)
                                            .frame(width: 32, height: 32)
                                            .accessibilityLabel("Message \(profile.username)")
                                            
                                            Button("Remove", role: .destructive) {
                                                Task { await removeFriend(profile.uid) }
                                            }
                                            .font(.subheadline)
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.95))
                                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                                        )
                                        .frame(maxWidth: 360)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                }
                            }
                        }
                        if !pendingSentProfiles.isEmpty {
                            Section("Pending") {
                                ForEach(pendingSentProfiles, id: \.uid) { profile in
                                    HStack {
                                        Spacer(minLength: 0)
                                        
                                        HStack(spacing: 10) {
                                            profileButton(for: profile)
                                            Spacer(minLength: 8)
                                            Text("Pending")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Button("Cancel", role: .destructive) {
                                                Task { await cancelRequest(profile.uid) }
                                            }
                                            .buttonStyle(.bordered)
                                            .font(.subheadline)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white.opacity(0.95))
                                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                                        )
                                        .frame(maxWidth: 360)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            Task { await cancelRequest(profile.uid) }
                                        } label: {
                                            Label("Cancel request", systemImage: "xmark.circle")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden) // let the FriendsBackground show through
                }
            }
        }
        .navigationTitle("") // we'll render a custom styled title instead
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Styled "Friends" title with capsule background, like Home
            ToolbarItem(placement: .principal) {
                Text("Friends")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.systemGray5)))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoggedIn {
                    Button(action: { showAddFriend = true }) {
                        Label("Add friend", systemImage: "person.badge.plus")
                    }
                }
            }
        }
        .task(id: Auth.auth().currentUser?.uid) {
            await loadFriendsWithCache()
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let profile = profileToOpen {
                        UserProfileView(profile: profile)
                    }
                },
                isActive: Binding(
                    get: { profileToOpen != nil },
                    set: { if !$0 { profileToOpen = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        )
        .sheet(isPresented: $showAddFriend) {
            AddFriendView(userService: userService) {
                showAddFriend = false
                Task { await refreshAll() }
            }
        }
    }
    
    /// Show cached list immediately (if any), then refresh from Firestore in the background.
    private func loadFriendsWithCache() async {
        guard isLoggedIn, let uid = Auth.auth().currentUser?.uid else {
            await MainActor.run { isLoading = false }
            return
        }
        if let cached = UserService.friendsListDisplayCache(forUserId: uid) {
            await MainActor.run {
                friends = cached.friends
                pendingSentProfiles = cached.pendingSentProfiles
                pendingReceived = cached.pendingReceived
                isLoading = false
            }
            await loadFriendsFromServer(showBlockingSpinner: false)
        } else {
            await MainActor.run { isLoading = true }
            await loadFriendsFromServer(showBlockingSpinner: true)
        }
    }
    
    /// Full load from Firestore: friend IDs, pending IDs, then batch profile reads (not N sequential gets).
    private func loadFriendsFromServer(showBlockingSpinner: Bool) async {
        guard isLoggedIn, let uid = Auth.auth().currentUser?.uid else {
            await MainActor.run { isLoading = false }
            return
        }
        if showBlockingSpinner {
            await MainActor.run { isLoading = true }
        }
        print("[FriendsListView] loadFriendsFromServer starting")
        
        await userService.loadFriends()
        await userService.loadPendingSent()
        await userService.processAcceptedRequests()
        
        await userService.loadBlockedUsers()
        let friendProfiles = ((try? await userService.fetchProfiles(forUids: userService.friendIds)) ?? [])
            .filter { !userService.isBlocked(uid: $0.uid) }
        let pendingProfiles = ((try? await userService.fetchProfiles(forUids: userService.pendingSentIds)) ?? [])
            .filter { !userService.isBlocked(uid: $0.uid) }
        
        let requests = (try? await userService.loadPendingReceived()) ?? []
        let fromUids = requests.map(\.fromUid)
        let senderProfiles = (try? await userService.fetchProfiles(forUids: fromUids)) ?? []
        let profileById = Dictionary(uniqueKeysWithValues: senderProfiles.map { ($0.uid, $0) })
        let receivedPairs: [(FriendRequest, UserProfile)] = requests.compactMap { request in
            guard let profile = profileById[request.fromUid],
                  !userService.isBlocked(uid: request.fromUid) else {
                if profileById[request.fromUid] == nil {
                    print("[FriendsListView] loadPendingReceived: missing profile for fromUid=\(request.fromUid)")
                }
                return nil
            }
            return (request, profile)
        }
        
        let cache = FriendsListDisplayCache(
            userId: uid,
            friends: friendProfiles,
            pendingSentProfiles: pendingProfiles,
            pendingReceived: receivedPairs,
            loadedAt: Date()
        )
        UserService.storeFriendsListDisplayCache(cache)
        
        await MainActor.run {
            friends = friendProfiles
            pendingSentProfiles = pendingProfiles
            pendingReceived = receivedPairs
            isLoading = false
        }
        print("[FriendsListView] loadFriendsFromServer finished. friends=\(friends.count), pendingSent=\(pendingSentProfiles.count), pendingReceived=\(pendingReceived.count)")
    }
    
    /// Refresh friends and pending lists from Firestore (e.g. after adding a friend).
    private func refreshAll() async {
        guard isLoggedIn else { return }
        await loadFriendsFromServer(showBlockingSpinner: false)
    }
    
    private func removeFriend(_ uid: String) async {
        do {
            try await userService.removeFriend(friendUid: uid)
            await refreshAll()
        } catch {
            print("Error removing friend: \(error)")
        }
    }
    
    private func cancelRequest(_ toUid: String) async {
        do {
            try await userService.cancelFriendRequest(toUid: toUid)
            await refreshAll()
        } catch {
            print("Error canceling request: \(error)")
        }
    }
    
    private func acceptRequest(_ fromUid: String) async {
        do {
            try await userService.acceptFriendRequest(fromUid: fromUid)
            await refreshAll()
        } catch {
            print("Error accepting request: \(error)")
        }
    }
    
    private func profileButton(for profile: UserProfile) -> some View {
        Button {
            profileToOpen = profile
        } label: {
            FriendIdentity(profile: profile)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(profile.username)'s profile")
    }
    
    private func declineRequest(_ fromUid: String) async {
        do {
            try await userService.declineFriendRequest(fromUid: fromUid)
            await refreshAll()
        } catch {
            print("Error declining request: \(error)")
        }
    }
}

private struct FriendIdentity: View {
    let profile: UserProfile
    
    var body: some View {
        HStack(spacing: 12) {
            avatarView
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.username)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var avatarView: some View {
        Group {
            if let urlString = profile.avatarURL, let url = URL(string: urlString) {
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
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
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
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.body)
            )
    }
}

#Preview {
    NavigationStack {
        FriendsListView()
            .environmentObject(ActivityService())
    }
}
