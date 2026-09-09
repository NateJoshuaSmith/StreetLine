//
//  AddFriendView.swift
//  SpotFinder
//
//  Search users by username and add them as friends.
//

import SwiftUI
import FirebaseAuth

struct AddFriendView: View {
    @ObservedObject var userService: UserService
    var onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    private let actionGreen = Color(red: 0.12, green: 0.62, blue: 0.38)
    private let inkMuted = Color.black.opacity(0.72)
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    /// Results to show: exclude self and already friends; mark just-added.
    private var displayResults: [UserProfile] {
        guard let uid = currentUid else { return [] }
        return searchResults.filter { $0.uid != uid && !userService.isBlocked(uid: $0.uid) }
    }
    
    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArtBackdrop(imageName: "FriendsBackground", dim: 0.42, starBand: .header)
                
                VStack(spacing: 14) {
                    StreetlineCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("USERNAME")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.black)
                            
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.body.weight(.bold))
                                    .foregroundColor(.black)
                                TextField("Search by username", text: $searchText)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.black)
                                    .onSubmit { Task { await runSearch() } }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            
                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    resultsBody
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                StreetlineSheetHeader(title: "Add friend") {
                    dismiss()
                    onDismiss()
                }
            }
            .task {
                await userService.loadPendingSent()
            }
            .onChange(of: searchText) { _, newValue in
                let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.count >= 2 {
                    Task { await runSearch() }
                } else {
                    searchResults = []
                    errorMessage = nil
                }
            }
        }
    }
    
    @ViewBuilder
    private var resultsBody: some View {
        if isSearching {
            StreetlineCard {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.black)
                    Text("Searching…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            Spacer()
        } else if displayResults.isEmpty && !trimmedQuery.isEmpty {
            EmptyStateCard(
                title: "No users found",
                systemImage: "person.crop.circle.badge.questionmark",
                message: "Try a different username."
            )
        } else if displayResults.isEmpty {
            StreetlineCard {
                VStack(spacing: 8) {
                    Text("Find a skater")
                        .font(.headline.weight(.heavy))
                        .foregroundColor(.black)
                    Text("Type at least 2 letters of their username.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(inkMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            Spacer()
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(displayResults, id: \.uid) { profile in
                        StreetlineCard {
                            AddFriendRow(
                                profile: profile,
                                isFriend: userService.isFriend(uid: profile.uid),
                                isPendingSent: userService.hasPendingSentRequest(toUid: profile.uid),
                                actionGreen: actionGreen,
                                onAdd: { Task { await sendFriendRequest(profile.uid) } }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
    
    private func runSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            await MainActor.run { searchResults = []; errorMessage = nil }
            return
        }
        await MainActor.run { isSearching = true; errorMessage = nil }
        do {
            let results = try await userService.searchUsers(byUsernamePrefix: query)
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            await MainActor.run {
                isSearching = false
                searchResults = []
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
    
    private func sendFriendRequest(_ toUid: String) async {
        do {
            try await userService.createFriendRequest(toUid: toUid)
        } catch {
            await MainActor.run {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}

private struct AddFriendRow: View {
    let profile: UserProfile
    let isFriend: Bool
    let isPendingSent: Bool
    let actionGreen: Color
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            avatarView
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.username)
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.black)
                Text("@\(profile.username)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.black.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if isFriend {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(actionGreen)
            } else if isPendingSent {
                Text("PENDING")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black, lineWidth: 2)
                    )
            } else {
                Button(action: onAdd) {
                    Text("ADD")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(actionGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black, lineWidth: 2.5)
                        )
                }
                .buttonStyle(.plain)
            }
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
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
            } else {
                avatarPlaceholder
            }
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(red: 0.18, green: 0.78, blue: 1.0))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.black)
                    .font(.body.weight(.bold))
            )
            .overlay(Circle().stroke(Color.black, lineWidth: 2))
    }
}

#Preview {
    AddFriendView(userService: UserService(), onDismiss: {})
}
