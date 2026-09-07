//
//  LobbyView.swift
//  Streetline
//
//  Shared global chat room.
//

import SwiftUI
import FirebaseAuth

struct LobbyView: View {
    @StateObject private var lobbyService = LobbyService()
    @StateObject private var userService = UserService()
    @State private var messages: [LobbyMessage] = []
    @State private var inputText = ""
    @State private var currentUsername = ""
    @State private var cancelListening: (() -> Void)?
    @State private var messageToReport: LobbyMessage?
    @State private var userToBlock: (uid: String, username: String)?
    @State private var errorMessage: String?
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var showReport: Binding<Bool> {
        Binding(
            get: { messageToReport != nil },
            set: { if !$0 { messageToReport = nil } }
        )
    }
    
    private var showBlockDialog: Binding<Bool> {
        Binding(
            get: { userToBlock != nil },
            set: { if !$0 { userToBlock = nil } }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty, errorMessage == nil {
                            Text("Say something to the lobby.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        }
                        ForEach(messages) { message in
                            lobbyBubble(message)
                                .id(message.id)
                                .contextMenu {
                                    if message.senderId != currentUserId {
                                        Button {
                                            messageToReport = message
                                        } label: {
                                            Label("Report", systemImage: "flag")
                                        }
                                        Button(role: .destructive) {
                                            userToBlock = (message.senderId, message.senderUsername)
                                        } label: {
                                            Label("Block @\(message.senderUsername)", systemImage: "hand.raised")
                                        }
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastId = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            VStack(spacing: 6) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 12) {
                    TextField("Message the lobby", text: $inputText, axis: .vertical)
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
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .navigationTitle("Lobby")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            startListening()
            async let blocked: Void = userService.loadBlockedUsers()
            async let purged: Void = lobbyService.deleteExpiredMessages()
            let name = await userService.getCurrentUsername()
            currentUsername = name ?? ""
            await blocked
            await purged
        }
        .sheet(isPresented: showReport) {
            if let message = messageToReport {
                ReportContentView(
                    title: "Report Message",
                    prompt: "Why are you reporting this message?",
                    type: .message,
                    targetId: message.id ?? "",
                    targetPreview: message.text,
                    reportedUserId: message.senderId,
                    onDismiss: { messageToReport = nil }
                )
            }
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: showBlockDialog,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let user = userToBlock {
                    Task {
                        try? await userService.blockUser(user.uid)
                        messages = messages.filter { !UserService.isUserBlocked($0.senderId) }
                    }
                }
                userToBlock = nil
            }
            Button("Cancel", role: .cancel) { userToBlock = nil }
        } message: {
            if let user = userToBlock {
                Text("You won't see messages from @\(user.username) in the lobby.")
            }
        }
        .onDisappear {
            cancelListening?()
            cancelListening = nil
        }
    }
    
    private func lobbyBubble(_ message: LobbyMessage) -> some View {
        let isMine = message.senderId == currentUserId
        let rawName = message.senderUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = isMine ? (currentUsername.isEmpty ? "You" : currentUsername) : (rawName.isEmpty ? "Unknown" : rawName)
        let initial = String(name.prefix(1)).uppercased()
        
        return HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(initial)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.black)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isMine ? "You" : "@\(name)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primary)
                
                HStack {
                    if isMine { Spacer(minLength: 40) }
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMine ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isMine ? .white : .primary)
                        .cornerRadius(16)
                    if !isMine { Spacer(minLength: 40) }
                }
            }
        }
    }
    
    private func startListening() {
        cancelListening?()
        cancelListening = lobbyService.listenToMessages(
            onUpdate: { updated in
                messages = updated
                errorMessage = nil
            },
            onError: { message in
                errorMessage = message
            }
        )
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let uid = currentUserId else { return }
        inputText = ""
        errorMessage = nil
        
        let local = LobbyMessage(
            id: UUID().uuidString,
            senderId: uid,
            senderUsername: currentUsername.isEmpty ? "You" : currentUsername,
            text: text,
            createdAt: Date()
        )
        messages.append(local)
        
        Task {
            do {
                try await lobbyService.send(text: text, username: currentUsername.isEmpty ? "You" : currentUsername)
            } catch {
                await MainActor.run {
                    messages.removeAll { $0.id == local.id }
                    errorMessage = error.localizedDescription
                    inputText = text
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LobbyView()
    }
}
