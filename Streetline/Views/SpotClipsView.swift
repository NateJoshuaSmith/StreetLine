//
//  SpotClipsView.swift
//  Streetline
//
//  Watch and post trick clips for a skate spot.
//

import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import CoreTransferable
import FirebaseAuth

struct VideoFileTransfer: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mp4" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return VideoFileTransfer(url: dest)
        }
    }
}

struct SpotClipsView: View {
    let spot: SkateSpot
    
    @StateObject private var clipService = ClipService()
    @StateObject private var userService = UserService()
    @State private var clips: [SpotClip] = []
    @State private var isLoading = true
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var playingClip: SpotClip?
    @State private var clipToReport: SpotClip?
    @State private var userToBlock: (uid: String, username: String)?
    @Environment(\.dismiss) private var dismiss
    
    private var isLoggedIn: Bool {
        Auth.auth().currentUser != nil
    }
    
    private var showClipReport: Binding<Bool> {
        Binding(
            get: { clipToReport != nil },
            set: { if !$0 { clipToReport = nil } }
        )
    }
    
    private var showBlockDialog: Binding<Bool> {
        Binding(
            get: { userToBlock != nil },
            set: { if !$0 { userToBlock = nil } }
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let playingClip, let url = URL(string: playingClip.videoURL) {
                    ClipPlayerView(url: url)
                        .id(playingClip.id)
                        .frame(height: 240)
                    if let name = playingClip.createdByUsername, !name.isEmpty {
                        Text("@\(name)")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }
                
                if isLoading {
                    Spacer()
                    ProgressView("Loading clips…")
                    Spacer()
                } else if clips.isEmpty {
                    EmptyStateCard(
                        title: "No clips yet",
                        systemImage: "film",
                        message: isLoggedIn
                            ? "Be the first to post a trick from this spot."
                            : "Sign in to post a clip from this spot."
                    )
                } else {
                    List {
                        ForEach(clips) { clip in
                            Button {
                                playingClip = clip
                            } label: {
                                HStack(spacing: 12) {
                                    ClipThumbnailView(clip: clip, size: 64)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(clip.createdByUsername.map { "@\($0)" } ?? "Clip")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.primary)
                                        Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let caption = clip.caption, !caption.isEmpty {
                                            Text(caption)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if clip.createdBy == Auth.auth().currentUser?.uid, let spotId = spot.id {
                                    Button(role: .destructive) {
                                        Task { await deleteClip(clip, spotId: spotId) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } else if isLoggedIn {
                                    Button {
                                        clipToReport = clip
                                    } label: {
                                        Label("Report", systemImage: "flag")
                                    }
                                    .tint(.orange)
                                    Button(role: .destructive) {
                                        userToBlock = (clip.createdBy, clip.createdByUsername ?? "user")
                                    } label: {
                                        Label("Block", systemImage: "hand.raised")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Clips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isLoggedIn {
                        if isUploading {
                            ProgressView()
                        } else {
                            PhotosPicker(selection: $selectedItem, matching: .videos) {
                                Label("Add clip", systemImage: "plus")
                            }
                        }
                    }
                }
            }
            .task {
                await reload()
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task { await upload(item) }
            }
            .sheet(isPresented: showClipReport) {
                if let clip = clipToReport {
                    ReportContentView(
                        title: "Report Clip",
                        prompt: "Why are you reporting this clip?",
                        type: .spotClip,
                        targetId: clip.id ?? "",
                        targetPreview: clip.caption ?? clip.createdByUsername,
                        reportedUserId: clip.createdBy,
                        spotId: spot.id,
                        spotName: spot.name,
                        onDismiss: { clipToReport = nil }
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
                        Task { try? await userService.blockUser(user.uid) }
                    }
                    userToBlock = nil
                    Task { await reload() }
                    if let playing = playingClip, UserService.isUserBlocked(playing.createdBy) {
                        playingClip = nil
                    }
                }
                Button("Cancel", role: .cancel) { userToBlock = nil }
            } message: {
                if let user = userToBlock {
                    Text("You won't see clips from @\(user.username).")
                }
            }
        }
    }
    
    private func reload() async {
        guard let spotId = spot.id else {
            await MainActor.run { isLoading = false }
            return
        }
        let loaded = await clipService.fetchClips(spotId: spotId)
        await MainActor.run {
            clips = loaded
            isLoading = false
        }
    }
    
    private func upload(_ item: PhotosPickerItem) async {
        guard let spotId = spot.id else { return }
        await MainActor.run {
            isUploading = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in
                isUploading = false
                selectedItem = nil
            }
        }
        do {
            guard let movie = try await item.loadTransferable(type: VideoFileTransfer.self) else {
                throw NSError(domain: "ClipService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Could not load that video"])
            }
            try await clipService.uploadClip(spotId: spotId, videoFileURL: movie.url)
            await reload()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func deleteClip(_ clip: SpotClip, spotId: String) async {
        do {
            try await clipService.deleteClip(spotId: spotId, clip: clip)
            await reload()
            if playingClip?.id == clip.id {
                await MainActor.run {
                    playingClip = nil
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

struct ClipPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .background(Color.black)
            .onAppear {
                let avPlayer = AVPlayer(url: url)
                player = avPlayer
                avPlayer.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}

/// Compact clips row for the map pin callout.
struct CalloutClipsRow: View {
    let spot: SkateSpot
    let onOpen: () -> Void
    
    @State private var clips: [SpotClip] = []
    @State private var isLoading = true
    
    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Label("Clips", systemImage: "film")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                    Spacer(minLength: 4)
                    Text(clips.isEmpty && !isLoading ? "Add" : "See all")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.blue)
                }
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading…")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 44)
                } else if clips.isEmpty {
                    Text("No tricks posted yet")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(height: 20, alignment: .leading)
                } else {
                    HStack(spacing: 6) {
                        ForEach(Array(clips.prefix(4))) { clip in
                            ClipThumbnailView(clip: clip, size: 44)
                        }
                        if clips.count > 4 {
                            Text("+\(clips.count - 4)")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: spot.id) {
            guard let id = spot.id else {
                isLoading = false
                return
            }
            let loaded = await ClipService().fetchClips(spotId: id, limit: 8)
            clips = loaded
            isLoading = false
        }
    }
}

struct ClipThumbnailView: View {
    let clip: SpotClip
    var size: CGFloat = 56
    
    var body: some View {
        ZStack {
            if let urlString = clip.thumbnailURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(Color(.systemGray5))
                    }
                }
            } else {
                Rectangle().fill(Color(.systemGray5))
            }
            Image(systemName: "play.fill")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .shadow(radius: 2)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }
}
