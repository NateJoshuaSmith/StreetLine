//
//  ConversationView.swift
//  SpotFinder
//
//  1:1 chat with a friend. Matches the Lobby chat look.
//

import SwiftUI
import FirebaseAuth

struct ConversationView: View {
    let friendProfile: UserProfile
    
    @EnvironmentObject var activityService: ActivityService
    @StateObject private var threadService = ThreadService()
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var threadId: String?
    @State private var isReady = false
    @State private var cancelListening: (() -> Void)?
    @StateObject private var userService = UserService()
    @State private var showReportUser = false
    @State private var showReportMessages = false
    @State private var showBlockConfirm = false
    @State private var errorMessage: String?
    
    private var isBlocked: Bool {
        userService.isBlocked(uid: friendProfile.uid)
    }
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var friendTitle: String {
        let name = friendProfile.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Chat" : name
    }
    
    var body: some View {
        ZStack {
            ArtBackdrop(imageName: "LobbyBackgroudImage", dim: 0.22, starBand: .lobby)
            
            VStack(spacing: 0) {
                if !isReady {
                    ProgressView("Starting conversation...")
                        .tint(.black)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.vertical, 28)
                        .padding(.horizontal, 32)
                        .background(chatBubbleFill)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if messages.isEmpty, errorMessage == nil {
                                    Text("Say something to @\(friendProfile.username).")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(chatBubbleFill)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                                        .padding(.top, 24)
                                }
                                ForEach(messages, id: \.stableId) { message in
                                    FriendChatBubble(
                                        message: message,
                                        isMine: message.senderId == currentUserId,
                                        friendName: friendTitle
                                    )
                                    .id(message.stableId)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .scrollContentBackground(.hidden)
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(last.stableId, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    VStack(spacing: 6) {
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if isBlocked {
                            VStack(spacing: 8) {
                                Text("You blocked this user.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button("Unblock") {
                                    Task { try? await userService.unblockUser(friendProfile.uid) }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            HStack(spacing: 12) {
                                TextField("Message \(friendProfile.username)", text: $inputText, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .lineLimit(1...4)
                                    .onSubmit { sendMessage() }
                                Button(action: sendMessage) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                                }
                                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.94))
                }
            }
        }
        .navigationTitle(friendTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(friendTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.95)))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showReportMessages = true
                    } label: {
                        Label("Report messages", systemImage: "flag")
                    }
                    Button {
                        showReportUser = true
                    } label: {
                        Label("Report user", systemImage: "person.crop.circle.badge.exclamationmark")
                    }
                    if isBlocked {
                        Button {
                            Task { try? await userService.unblockUser(friendProfile.uid) }
                        } label: {
                            Label("Unblock", systemImage: "hand.raised.slash")
                        }
                    } else {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("Block", systemImage: "hand.raised")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showReportUser) {
            ReportContentView(
                title: "Report User",
                prompt: "Why are you reporting this account?",
                type: .user,
                targetId: friendProfile.uid,
                targetPreview: friendProfile.username,
                reportedUserId: friendProfile.uid,
                onDismiss: { showReportUser = false }
            )
        }
        .sheet(isPresented: $showReportMessages) {
            ReportContentView(
                title: "Report Messages",
                prompt: "Why are you reporting this conversation?",
                type: .message,
                targetId: threadId ?? friendProfile.uid,
                targetPreview: messages.last?.text,
                reportedUserId: friendProfile.uid,
                onDismiss: { showReportMessages = false }
            )
        }
        .confirmationDialog(
            "Block @\(friendProfile.username)?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task { try? await userService.blockUser(friendProfile.uid) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("They won't be able to message you from this chat.")
        }
        .task {
            activityService.markConversationOpened(withFriendUid: friendProfile.uid)
            await userService.loadBlockedUsers()
            await setupThread()
        }
        .onDisappear {
            cancelListening?()
        }
    }
    
    private var chatBubbleFill: Color {
        Color.white.opacity(0.96)
    }
    
    private func setupThread() async {
        do {
            let thread = try await threadService.createOrGetThread(withFriendUid: friendProfile.uid)
            let tid = thread.id ?? Thread.threadId(between: friendProfile.uid, and: currentUserId ?? "")
            await MainActor.run {
                threadId = tid
                isReady = true
            }
            await threadService.markThreadAsRead(threadId: tid)
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
        guard !text.isEmpty, let tid = threadId, let uid = currentUserId, !isBlocked else { return }
        inputText = ""
        errorMessage = nil
        
        let local = Message(id: UUID().uuidString, senderId: uid, text: text, createdAt: Date())
        messages.append(local)
        
        Task {
            do {
                try await threadService.sendMessage(threadId: tid, text: text)
            } catch {
                await MainActor.run {
                    messages.removeAll { $0.id == local.id }
                    errorMessage = error.localizedDescription
                    inputText = text
                }
                print("Send message error: \(error)")
            }
        }
    }
}

private struct FriendChatBubble: View {
    let message: Message
    let isMine: Bool
    let friendName: String
    
    private var chatBubbleFill: Color {
        Color.white.opacity(0.96)
    }
    
    var body: some View {
        let name = isMine ? "You" : (friendName.isEmpty ? "Unknown" : friendName)
        let initial = String(name.prefix(1)).uppercased()
        
        HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 48) }
            
            if !isMine {
                Circle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(initial)
                            .font(.caption.weight(.bold))
                            .foregroundColor(.black)
                    )
            }
            
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(isMine ? "You" : "@\(name)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                
                Text(message.text)
                    .font(.body)
                    .foregroundColor(isMine ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMine ? Color.blue : chatBubbleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
            }
            
            if !isMine { Spacer(minLength: 48) }
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(friendProfile: UserProfile(uid: "preview", username: "friend", email: nil, avatarURL: nil))
            .environmentObject(ActivityService())
    }
}
