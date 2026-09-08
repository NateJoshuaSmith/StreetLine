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
        ZStack {
            ArtBackdrop(imageName: "LobbyBackgroudImage", dim: 0.22)
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty, errorMessage == nil {
                                Text("Say something to the lobby.")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(chatBubbleFill)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .scrollContentBackground(.hidden)
                    .onChange(of: messages.count) { _, _ in
                        if let lastId = messages.last?.id {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
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
                    HStack(spacing: 12) {
                        TextField("Message the lobby", text: $inputText, axis: .vertical)
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
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.94))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Lobby")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.95)))
            }
        }
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
    
    private var chatBubbleFill: Color {
        Color.white.opacity(0.96)
    }
    
    private func lobbyBubble(_ message: LobbyMessage) -> some View {
        let isMine = message.senderId == currentUserId
        let rawName = message.senderUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = isMine ? (currentUsername.isEmpty ? "You" : currentUsername) : (rawName.isEmpty ? "Unknown" : rawName)
        let initial = String(name.prefix(1)).uppercased()
        
        return HStack(alignment: .bottom, spacing: 8) {
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
