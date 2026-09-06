//
//  ConversationView.swift
//  SpotFinder
//
//  1:1 chat with a friend.
//

import SwiftUI
import FirebaseAuth

struct ConversationView: View {
    let friendProfile: UserProfile
    
    @StateObject private var threadService = ThreadService()
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var threadId: String?
    @State private var isReady = false
    @State private var cancelListening: (() -> Void)?
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !isReady {
                ProgressView("Starting conversation...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.senderId == currentUserId,
                                    friendUsername: friendProfile.username,
                                    friendAvatarURL: friendProfile.avatarURL
                                )
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                HStack(spacing: 12) {
                    TextField("Message", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .onSubmit { sendMessage() }
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(friendProfile.username)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await setupThread()
        }
        .onDisappear {
            cancelListening?()
        }
    }
    
    private func setupThread() async {
        do {
            let thread = try await threadService.createOrGetThread(withFriendUid: friendProfile.uid)
            let tid = thread.id ?? Thread.threadId(between: friendProfile.uid, and: currentUserId ?? "")
            await MainActor.run {
                threadId = tid
                isReady = true
            }
            let cancel = threadService.listenToMessages(threadId: tid) { newMessages in
                messages = newMessages
            }
            await MainActor.run {
                cancelListening = cancel
            }
        } catch {
            await MainActor.run { isReady = true }
            print("ConversationView setup error: \(error)")
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let tid = threadId else { return }
        inputText = ""
        Task {
            do {
                try await threadService.sendMessage(threadId: tid, text: text)
            } catch {
                print("Send message error: \(error)")
            }
        }
    }
}

private struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let friendUsername: String
    let friendAvatarURL: String?
    
    var body: some View {
        // Display name for this bubble
        let displayName = isFromCurrentUser ? "You" : friendUsername
        let initial = String(displayName.prefix(1)).uppercased()
        
        HStack(alignment: .top, spacing: 8) {
            // Avatar always on the left
            if !isFromCurrentUser, let urlString = friendAvatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Text(initial)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.black)
                            )
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(initial)
                            .font(.caption.weight(.bold))
                            .foregroundColor(.black)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                // Bold, black username label on the left, like "username:"
                Text("\(displayName):")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                HStack {
                    if isFromCurrentUser {
                        Spacer(minLength: 40)
                    }
                    
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                    
                    if !isFromCurrentUser {
                        Spacer(minLength: 40)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(friendProfile: UserProfile(uid: "preview", username: "friend", email: nil, avatarURL: nil))
    }
}
