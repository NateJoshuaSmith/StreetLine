//
//  SpotDetailView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI
import FirebaseAuth
import PhotosUI
import MapKit

struct SpotDetailView: View {
    let spot: SkateSpot
    @ObservedObject var spotService: SpotService
    @StateObject private var commentService = CommentService()
    @StateObject private var userService = UserService()
    @StateObject private var reportService = ReportService()
    @Environment(\.dismiss) var dismiss
    
    @State private var showDeleteAlert = false
    @State private var showReportSheet = false
    @State private var commentToReport: SpotComment?
    @State private var userToBlock: (uid: String, username: String)?
    @State private var isTogglingFavorite = false
    @State private var showDeletePhotoAlert = false
    @State private var isDeleting = false
    @State private var isDeletingPhoto = false
    @State private var errorMessage: String?
    @State private var newCommentText = ""
    @State private var isPostingComment = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var localImageURL: String?  // Shows newly added photo before parent refreshes
    @State private var localImageURLsOverride: [String]? // Local source of truth after edits
    @State private var showPhotoPickerSheet = false
    @State private var selectedImageIndex: Int = 0
    @State private var pendingDeleteImageIndex: Int?
    @State private var averageRating: Double = 0
    @State private var ratingCount: Int = 0
    @State private var userRating: Int = 0
    @State private var isSubmittingRating = false
    @State private var showClipsSheet = false
    
    private let stickerBlue = Color(red: 0.08, green: 0.32, blue: 0.78)
    private let inkMuted = Color.black.opacity(0.75)
    
    // Check if current user owns this spot
    private var isOwner: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return spot.createdBy == currentUserId
    }
    
    private var placeholderPhotoView: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    if isOwner {
                        Text("Tap to add photo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            )
            .cornerRadius(16)
    }
    
    @ViewBuilder
    private func photoForURLString(_ urlString: String) -> some View {
        if let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    placeholderPhotoView
                case .empty:
                    placeholderPhotoView
                        .overlay(ProgressView())
                @unknown default:
                    placeholderPhotoView
                }
            }
        } else {
            placeholderPhotoView
        }
    }
    
    /// URLs to show for the spot photos: newly uploaded (local) plus stored on the spot
    private var displayedImageURLs: [String] {
        // Prefer locally overridden list if present (after adds/deletes)
        var urls = localImageURLsOverride ?? (spot.imageURLs ?? [])
        
        // Fallback to legacy single imageURL
        if urls.isEmpty, let single = spot.imageURL {
            urls = [single]
        }
        
        // Ensure local (newly uploaded) URL is included
        if let local = localImageURL, !urls.contains(local) {
            urls.append(local)
        }
        
        return urls
    }
    
    private var visibleSpotComments: [SpotComment] {
        commentService.comments.filter { !UserService.isUserBlocked($0.createdBy) }
    }
    
    private var hasSpotDescription: Bool {
        let text = spot.comment.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.caseInsensitiveCompare("No comment") != .orderedSame
    }
    
    private var showCommentReport: Binding<Bool> {
        Binding(
            get: { commentToReport != nil },
            set: { if !$0 { commentToReport = nil } }
        )
    }
    
    private var showBlockDialog: Binding<Bool> {
        Binding(
            get: { userToBlock != nil },
            set: { if !$0 { userToBlock = nil } }
        )
    }
    
    private var photoPickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose a photo for this spot")
                    .font(.headline)
                    .foregroundColor(.black)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose from library", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showPhotoPickerSheet = false
                    }
                }
            }
        }
    }
    
    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: 400, alignment: .leading)
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black, lineWidth: 2.5)
            )
            .frame(maxWidth: .infinity)
    }
    
    private var titleCapsule: some View {
        ZStack {
            Capsule().fill(Color.white)
            Capsule().strokeBorder(Color.black, lineWidth: 2.5)
        }
    }
    
    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.heavy))
            .foregroundColor(.black)
    }
    
    private func infoChip(_ text: String, filled: Bool = false) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(filled ? stickerBlue.opacity(0.22) : Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.black, lineWidth: 2))
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
    
    private var spotDetailStack: some View {
        VStack(spacing: 14) {
            photoSection
            streetViewCard
            clipsCard
            nameCard
            if hasSpotDescription {
                descriptionCard
            }
            ratingCard
            addedCard
            commentsSection
            if isOwner {
                deleteSpotButton
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 32)
    }
    
    private var streetViewCard: some View {
        detailCard {
            StreetViewCard(
                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                title: spot.name
            )
        }
    }
    
    private var clipsCard: some View {
        detailCard {
            Button {
                showClipsSheet = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        sectionLabel("Clips", systemImage: "film")
                        Text("Watch tricks filmed at this spot")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(inkMuted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var photoSection: some View {
        if !displayedImageURLs.isEmpty {
            let urls = displayedImageURLs
            ZStack(alignment: .bottomTrailing) {
                TabView(selection: $selectedImageIndex) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                        photoForURLString(urlString)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black, lineWidth: 2.5)
                )
                
                if isOwner {
                    HStack {
                        Button(action: { showPhotoPickerSheet = true }) {
                            Image(systemName: "camera.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                        .disabled(isUploadingPhoto || isDeletingPhoto)
                        
                        Button(action: {
                            pendingDeleteImageIndex = selectedImageIndex
                            showDeletePhotoAlert = true
                        }) {
                            Image(systemName: "trash.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 24)
                        .padding(.bottom, 16)
                        .disabled(isUploadingPhoto || isDeletingPhoto)
                    }
                }
            }
        } else {
            VStack(spacing: 10) {
                ApplePlacePhotoView(
                    coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                    height: 200
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black, lineWidth: 2.5)
                )
                if isOwner {
                    Button(action: { showPhotoPickerSheet = true }) {
                        stickerButton(
                            title: isUploadingPhoto ? "UPLOADING..." : "ADD YOUR OWN PHOTO",
                            systemImage: "photo.badge.plus",
                            fill: stickerBlue
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isUploadingPhoto)
                }
            }
        }
    }
    
    private var nameCard: some View {
        detailCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Text(spot.name)
                        .font(.title3.weight(.heavy))
                        .tracking(0.4)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if Auth.auth().currentUser != nil, let spotId = spot.id {
                        Button(action: { Task { await toggleFavorite() } }) {
                            if isTogglingFavorite {
                                ProgressView()
                                    .frame(width: 36, height: 36)
                            } else {
                                Image(systemName: userService.isFavorite(spotId: spotId) ? "heart.fill" : "heart")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(userService.isFavorite(spotId: spotId) ? .red : .black)
                                    .frame(width: 36, height: 36)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isTogglingFavorite)
                        .accessibilityLabel(userService.isFavorite(spotId: spotId) ? "Remove from favorites" : "Add to favorites")
                    }
                }
                
                HStack(spacing: 8) {
                    if let difficulty = spot.difficulty {
                        infoChip(difficulty, filled: true)
                    }
                    if let status = spot.status {
                        infoChip(status)
                    }
                }
                
                if let tags = spot.tags, !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags.prefix(4), id: \.self) { tag in
                            infoChip(tag)
                        }
                    }
                }
            }
        }
    }
    
    private var descriptionCard: some View {
        detailCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Description", systemImage: "text.bubble.fill")
                Text(spot.comment)
                    .font(.body.weight(.medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var ratingCard: some View {
        detailCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Spot Rating", systemImage: "star.bubble.fill")
                
                HStack(spacing: 8) {
                    Text(ratingCount > 0 ? String(format: "%.1f", averageRating) : "No ratings yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                    if ratingCount > 0 {
                        Text("(\(ratingCount))")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(inkMuted)
                    }
                }
                
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            Task { await submitRating(star) }
                        } label: {
                            Image(systemName: star <= userRating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(star <= userRating ? Color(red: 0.85, green: 0.55, blue: 0.05) : .black)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmittingRating || Auth.auth().currentUser == nil)
                    }
                }
                
                if Auth.auth().currentUser == nil {
                    Text("Sign in to rate this spot.")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(inkMuted)
                } else if userRating > 0 {
                    Text("Your rating: \(userRating) / 5")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(inkMuted)
                }
            }
        }
    }
    
    private var addedCard: some View {
        detailCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Added", systemImage: "calendar")
                
                Text(spot.createdAt, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black)
                
                Button {
                    openInMapsDirections()
                } label: {
                    stickerButton(
                        title: "DIRECTIONS",
                        systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                        fill: stickerBlue
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                
                if let username = spot.createdByUsername, !username.isEmpty {
                    NavigationLink(
                        destination: UserProfileView(
                            profile: UserProfile(uid: spot.createdBy, username: username)
                        )
                    ) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption.weight(.bold))
                            Text("by @\(username)")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
    }
    
    private var commentsSection: some View {
        detailCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Comments", systemImage: "bubble.left.and.bubble.right.fill")
                
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .lineLimit(1...4)
                    
                    Button(action: { Task { await postComment() } }) {
                        if isPostingComment {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(stickerBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black, lineWidth: 2.5)
                    )
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPostingComment)
                    .opacity(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
                
                ForEach(visibleSpotComments) { comment in
                    CommentRowView(
                        comment: comment,
                        spotId: spot.id ?? "",
                        commentService: commentService,
                        onReport: { commentToReport = comment },
                        onBlock: { userToBlock = (comment.createdBy, comment.createdByUsername ?? "user") }
                    )
                }
            }
        }
    }
    
    private var deleteSpotButton: some View {
        Button(action: { showDeleteAlert = true }) {
            stickerButton(
                title: isDeleting ? "DELETING..." : "DELETE SPOT",
                systemImage: "trash.fill",
                fill: Color.red
            )
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }
    
    private var headerCircleButton: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.black, lineWidth: 2.5))
    }
    
    private var spotDetailHeader: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color.white)
                .overlay(Capsule().stroke(Color.black, lineWidth: 2))
                .frame(width: 52, height: 7)
                .padding(.top, 8)
                .accessibilityHidden(true)
            
            ZStack {
                Text(spot.name)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(titleCapsule)
                    .padding(.horizontal, 88)
                
                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(headerCircleButton)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    
                    Spacer()
                    
                    if Auth.auth().currentUser != nil, let spotId = spot.id {
                        Button {
                            Task { await toggleFavorite() }
                        } label: {
                            Group {
                                if isTogglingFavorite {
                                    ProgressView()
                                } else {
                                    Image(systemName: userService.isFavorite(spotId: spotId) ? "heart.fill" : "heart")
                                        .font(.subheadline.weight(.heavy))
                                        .foregroundColor(userService.isFavorite(spotId: spotId) ? .red : .black)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .background(headerCircleButton)
                        }
                        .buttonStyle(.plain)
                        .disabled(isTogglingFavorite)
                    }
                    
                    Button {
                        showReportSheet = true
                    } label: {
                        Image(systemName: "flag")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(headerCircleButton)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Report spot")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArtBackdrop(imageName: "CityImage", dim: 0.22, starBand: .header)
                
                ScrollView(.vertical, showsIndicators: false) {
                    spotDetailStack
                        .padding(.horizontal, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                spotDetailHeader
            }
                .sheet(isPresented: $showReportSheet) {
                    ReportSpotView(
                        spot: spot,
                        reportService: reportService,
                        onDismiss: { showReportSheet = false }
                    )
                }
                .sheet(isPresented: showCommentReport) {
                    if let comment = commentToReport {
                        ReportContentView(
                            title: "Report Comment",
                            prompt: "Why are you reporting this comment?",
                            type: .spotComment,
                            targetId: comment.id ?? "",
                            targetPreview: comment.text,
                            reportedUserId: comment.createdBy,
                            spotId: spot.id,
                            spotName: spot.name,
                            onDismiss: { commentToReport = nil }
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
                    }
                    Button("Cancel", role: .cancel) { userToBlock = nil }
                } message: {
                    if let user = userToBlock {
                        Text("You won't see comments from @\(user.username).")
                    }
                }
                .alert("Delete Spot?", isPresented: $showDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        Task {
                            await deleteSpot()
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete \"\(spot.name)\"? This action cannot be undone.")
                }
                .alert("Remove Photo?", isPresented: $showDeletePhotoAlert) {
                    Button("Cancel", role: .cancel) {
                        pendingDeleteImageIndex = nil
                    }
                    Button("Delete Photo", role: .destructive) {
                        Task {
                            await deleteCurrentPhoto()
                        }
                    }
                } message: {
                    Text("Are you sure you want to remove this photo from the spot?")
                }
                .alert("Error", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("OK") {
                        errorMessage = nil
                    }
                } message: {
                    if let error = errorMessage {
                        Text(error)
                    }
                }
                .onAppear {
                    if let spotId = spot.id {
                        commentService.listenToComments(spotId: spotId)
                        Task { await loadRatingSummary(spotId: spotId) }
                    }
                    localImageURL = nil
                    Task {
                        await userService.loadFavorites()
                        await userService.loadBlockedUsers()
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard isOwner, let item = newItem else { return }
                    showPhotoPickerSheet = false
                    Task { await uploadSelectedPhoto(item) }
                }
                .sheet(isPresented: $showPhotoPickerSheet) {
                    photoPickerSheet
                }
                .sheet(isPresented: $showClipsSheet) {
                    SpotClipsView(spot: spot)
                }
                .onDisappear {
                    commentService.stopListening()
                }
        }
    }
    
    private func postComment() async {
            guard let spotId = spot.id else { return }
            let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            
            isPostingComment = true
            defer { isPostingComment = false }
            
            do {
                try await commentService.addComment(spotId: spotId, text: text)
                newCommentText = ""
            } catch {
                errorMessage = "Failed to post comment: \(error.localizedDescription)"
            }
        }
        
        private func deleteSpot() async {
            isDeleting = true
            
            do {
                try await spotService.deleteSpot(spot)
                dismiss()  // Close view after successful deletion
            } catch {
                errorMessage = "Failed to delete spot: \(error.localizedDescription)"
                isDeleting = false
            }
        }
        
        private func deleteCurrentPhoto() async {
            guard isOwner else { return }
            let urls = displayedImageURLs
            let index = pendingDeleteImageIndex ?? selectedImageIndex
            guard index >= 0, index < urls.count else {
                pendingDeleteImageIndex = nil
                return
            }
            
            let imageURLToDelete = urls[index]
            
            isDeletingPhoto = true
            pendingDeleteImageIndex = nil
            defer { isDeletingPhoto = false }
            
            do {
                try await spotService.deleteSpotImage(spot: spot, imageURL: imageURLToDelete)
                await MainActor.run {
                    var updated = urls
                    updated.removeAll { $0 == imageURLToDelete }
                    localImageURLsOverride = updated
                    if localImageURL == imageURLToDelete {
                        localImageURL = nil
                    }
                    if selectedImageIndex >= updated.count {
                        selectedImageIndex = max(0, updated.count - 1)
                    }
                }
            } catch {
                errorMessage = "Failed to delete photo: \(error.localizedDescription)"
            }
        }
        
        private func uploadSelectedPhoto(_ item: PhotosPickerItem) async {
            guard let spotId = spot.id else { return }
            isUploadingPhoto = true
            defer { isUploadingPhoto = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                    errorMessage = "Could not load photo."
                    return
                }
                let urlString = try await spotService.uploadSpotImage(data: data)
                try await spotService.updateSpotImage(spot: spot, imageURL: urlString)
                await MainActor.run {
                    // Build up a local source of truth so new photos appear immediately
                    var updated = displayedImageURLs
                    if !updated.contains(urlString) {
                        updated.append(urlString)
                    }
                    localImageURLsOverride = updated
                    localImageURL = nil
                    selectedPhotoItem = nil
                }
            } catch {
                errorMessage = "Failed to add photo: \(error.localizedDescription)"
            }
        }
        
        private func openInMapsDirections() {
            let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = spot.name
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
        }
        
        private func toggleFavorite() async {
            guard let spotId = spot.id else { return }
            isTogglingFavorite = true
            defer { isTogglingFavorite = false }
            do {
                if userService.isFavorite(spotId: spotId) {
                    try await userService.removeFavorite(spotId: spotId)
                } else {
                    try await userService.addFavorite(spotId: spotId)
                }
            } catch {
                errorMessage = "Failed to update favorite: \(error.localizedDescription)"
            }
        }
    
        private func loadRatingSummary(spotId: String) async {
            do {
                let summary = try await spotService.fetchRatingSummary(spotId: spotId)
                await MainActor.run {
                    averageRating = summary.average
                    ratingCount = summary.count
                    userRating = summary.userRating ?? 0
                }
            } catch {
                // keep UI usable; rating can silently fail if rules are missing
                print("Failed to load rating summary: \(error)")
            }
        }
    
        private func submitRating(_ rating: Int) async {
            guard let spotId = spot.id, Auth.auth().currentUser != nil else { return }
            isSubmittingRating = true
            defer { isSubmittingRating = false }
            do {
                try await spotService.submitRating(spotId: spotId, rating: rating)
                userRating = rating
                await loadRatingSummary(spotId: spotId)
            } catch {
                errorMessage = "Failed to submit rating: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Comment Row
    private struct CommentRowView: View {
        let comment: SpotComment
        let spotId: String
        @ObservedObject var commentService: CommentService
        var onReport: () -> Void
        var onBlock: () -> Void
        
        private var currentUserId: String? {
            Auth.auth().currentUser?.uid
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let username = comment.createdByUsername, !username.isEmpty {
                            Text("@\(username)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        } else {
                            Text("Anonymous")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Color.black.opacity(0.7))
                        }
                        Text(comment.text)
                            .font(.body.weight(.medium))
                            .foregroundColor(.black)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    // Like / Dislike buttons
                    HStack(spacing: 12) {
                        Button(action: { Task { try? await commentService.toggleLike(spotId: spotId, comment: comment) } }) {
                            HStack(spacing: 4) {
                                Image(systemName: comment.hasLiked(userId: currentUserId ?? "") ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .foregroundColor(comment.hasLiked(userId: currentUserId ?? "") ? Color(red: 0.08, green: 0.32, blue: 0.78) : .black)
                                Text("\(comment.likeCount)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.black)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { Task { try? await commentService.toggleDislike(spotId: spotId, comment: comment) } }) {
                            HStack(spacing: 4) {
                                Image(systemName: comment.hasDisliked(userId: currentUserId ?? "") ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                    .foregroundColor(comment.hasDisliked(userId: currentUserId ?? "") ? .red : .black)
                                Text("\(comment.dislikeCount)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.black)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(comment.createdAt, style: .relative)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color.black.opacity(0.65))
            }
            .padding(12)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black, lineWidth: 1.5)
            )
            .cornerRadius(10)
            .contextMenu {
                if comment.createdBy != currentUserId {
                    Button(action: onReport) {
                        Label("Report comment", systemImage: "flag")
                    }
                    Button(role: .destructive, action: onBlock) {
                        Label("Block", systemImage: "hand.raised")
                    }
                }
            }
        }
    }
    
    // MARK: - Report Spot
    struct ReportSpotView: View {
        let spot: SkateSpot
        @ObservedObject var reportService: ReportService
        var onDismiss: () -> Void
        
        @State private var selectedReasonId: String = ReportService.reportReasons[0].id
        @State private var commentText: String = ""
        @State private var isSubmitting = false
        @State private var errorMessage: String?
        @State private var showSuccess = false
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        Picker("Reason", selection: $selectedReasonId) {
                            ForEach(ReportService.reportReasons, id: \.id) { reason in
                                Text(reason.label).tag(reason.id)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text("Why are you reporting this spot?")
                    }
                    Section {
                        TextField("Additional details (optional)", text: $commentText, axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        Text("Details")
                    }
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                    }
                }
                .navigationTitle("Report Spot")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                            onDismiss()
                        }
                        .disabled(isSubmitting)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") {
                            Task { await submitReport() }
                        }
                        .disabled(isSubmitting)
                    }
                }
                .alert("Report submitted", isPresented: $showSuccess) {
                    Button("OK") {
                        dismiss()
                        onDismiss()
                    }
                } message: {
                    Text("Thank you. We'll review this report.")
                }
            }
        }
        
        private func submitReport() async {
            guard let spotId = spot.id else { return }
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                try await reportService.submitContentReport(
                    type: .spot,
                    targetId: spotId,
                    targetPreview: spot.name,
                    reportedUserId: spot.createdBy,
                    reason: selectedReasonId,
                    comment: commentText.isEmpty ? nil : commentText,
                    spotId: spotId,
                    spotName: spot.name
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    #Preview {
        SpotDetailView(
            spot: SkateSpot(
                name: "Test Spot",
                latitude: 37.7749,
                longitude: -122.4194,
                comment: "This is a great spot for skateboarding!",
                createdBy: "user123",
                createdByUsername: "skater_pro"
            ),
            spotService: SpotService()
        )
    }
