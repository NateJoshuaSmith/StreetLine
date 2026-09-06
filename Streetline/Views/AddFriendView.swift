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
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    /// Results to show: exclude self and already friends; mark just-added.
    private var displayResults: [UserProfile] {
        guard let uid = currentUid else { return [] }
        return searchResults.filter { $0.uid != uid }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by username", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await runSearch() } }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                
                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if displayResults.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No users found",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Try a different username.")
                    )
                    Spacer()
                } else if displayResults.isEmpty {
                    Spacer()
                    Text("Enter a username to search")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(displayResults, id: \.uid) { profile in
                            AddFriendRow(
                                profile: profile,
                                isFriend: userService.isFriend(uid: profile.uid),
                                isPendingSent: userService.hasPendingSentRequest(toUid: profile.uid),
                                onAdd: { Task { await sendFriendRequest(profile.uid) } }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
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
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            avatarView
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.username)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isFriend {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if isPendingSent {
                Text("Pending")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            } else {
                Button("Add", action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
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
    AddFriendView(userService: UserService(), onDismiss: {})
}
