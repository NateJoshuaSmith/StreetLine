//
//  CommunityForumView.swift
//  SpotFinder
//
//  Community page for posting "looking to skate" messages.
//

import SwiftUI
import CoreLocation
import FirebaseAuth

struct CommunityForumView: View {
    @StateObject private var communityService = CommunityService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var spotService = SpotService()
    @State private var posts: [CommunityPost] = []
    @State private var isShowingComposer = false
    @State private var loadError: String?
    @State private var removeListener: (() -> Void)?
    @State private var postToReport: CommunityPost?
    @State private var userToBlock: (uid: String, username: String)?
    @StateObject private var userService = UserService()
    @AppStorage("mapNearbyRadiusMiles") private var nearbyRadiusMiles: Double = 10
    
    private let nearbyRadiusChoices: [(label: String, miles: Double)] = [
        ("2 mi", 2),
        ("5 mi", 5),
        ("10 mi", 10),
        ("25 mi", 25),
        ("All", 0)
    ]
    private let metersPerMile = 1609.34
    
    private var nearbyRadiusLabel: String {
        nearbyRadiusMiles > 0 ? "\(Int(nearbyRadiusMiles)) mi" : "All"
    }
    
    private var unblockedPosts: [CommunityPost] {
        posts.filter { !$0.isExpired && !UserService.isUserBlocked($0.createdBy) }
    }
    
    private var visiblePosts: [CommunityPost] {
        unblockedPosts
            .filter { isWithinNearbyRadius($0) }
            .sorted { $0.displayWhen < $1.displayWhen }
    }
    
    private var hasPostsOutsideRadius: Bool {
        !unblockedPosts.isEmpty && visiblePosts.isEmpty
    }
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        ZStack {
            ArtBackdrop(imageName: "PostsBackground", dim: 0.28, starBand: .headerRaised)
            
            content
                .padding(.horizontal)
                .padding(.top, 10)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Skate With")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.95)))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Menu {
                        ForEach(nearbyRadiusChoices, id: \.miles) { choice in
                            Button {
                                nearbyRadiusMiles = choice.miles
                            } label: {
                                if nearbyRadiusMiles == choice.miles {
                                    Label(choice.label, systemImage: "checkmark")
                                } else {
                                    Text(choice.label)
                                }
                            }
                        }
                    } label: {
                        Label(nearbyRadiusLabel, systemImage: "location.circle")
                    }
                    Button {
                        isShowingComposer = true
                    } label: {
                        Image(systemName: "plus.bubble.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingComposer) {
            SkateWithComposerView { text, sessionAt, sessionWhat, spot, locationText in
                try await communityService.createPost(
                    text: text,
                    sessionAt: sessionAt,
                    sessionWhat: sessionWhat,
                    spot: spot,
                    locationText: locationText
                )
            }
        }
        .task {
            await userService.loadBlockedUsers()
            await spotService.fetchSpots()
            startLocationUpdates()
            startListening()
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                locationManager.startLocationUpdates()
            }
        }
        .sheet(isPresented: Binding(
            get: { postToReport != nil },
            set: { if !$0 { postToReport = nil } }
        )) {
            if let post = postToReport {
                ReportContentView(
                    title: "Report Post",
                    prompt: "Why are you reporting this post?",
                    type: .communityPost,
                    targetId: post.id ?? "",
                    targetPreview: post.text,
                    reportedUserId: post.createdBy,
                    onDismiss: { postToReport = nil }
                )
            }
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: Binding(
                get: { userToBlock != nil },
                set: { if !$0 { userToBlock = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let user = userToBlock {
                    Task {
                        try? await userService.blockUser(user.uid)
                        posts = posts.filter { !UserService.isUserBlocked($0.createdBy) }
                    }
                }
                userToBlock = nil
            }
            Button("Cancel", role: .cancel) {
                userToBlock = nil
            }
        } message: {
            if let user = userToBlock {
                Text("You won't see posts or comments from @\(user.username).")
            }
        }
        .onDisappear {
            removeListener?()
            removeListener = nil
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if let loadError, posts.isEmpty {
            VStack(spacing: 12) {
                SkateWithSafetyNote()
                bubbleStateCard(
                    title: "Could not load community posts",
                    systemImage: "exclamationmark.triangle",
                    message: loadError
                )
            }
        } else if visiblePosts.isEmpty {
            VStack(spacing: 12) {
                SkateWithSafetyNote()
                bubbleStateCard(
                    title: hasPostsOutsideRadius ? "No sessions nearby" : "No one's looking yet",
                    systemImage: "person.3.sequence.fill",
                    message: hasPostsOutsideRadius
                        ? "Widen the distance filter or post one close by."
                        : "Tap the + button to post when and where you're skating."
                )
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    SkateWithSafetyNote()
                    ForEach(visiblePosts, id: \.id) { post in
                        NavigationLink(destination: CommunityPostDetailView(post: post)) {
                            postCard(post)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if post.createdBy != currentUid {
                                Button {
                                    postToReport = post
                                } label: {
                                    Label("Report post", systemImage: "flag")
                                }
                                Button(role: .destructive) {
                                    userToBlock = (post.createdBy, post.createdByUsername)
                                } label: {
                                    Label("Block @\(post.createdByUsername)", systemImage: "hand.raised")
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    private func postCard(_ post: CommunityPost) -> some View {
        HStack {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.blue))
                    
                    NavigationLink(
                        destination: UserProfileView(
                            profile: UserProfile(uid: post.createdBy, username: post.createdByUsername)
                        )
                    ) {
                        Text("@\(post.createdByUsername)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                
                SessionPostMeta(post: post)
                
                if !post.text.isEmpty {
                    Text(post.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack {
                    Spacer()
                    Label("View replies", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(14)
            .frame(maxWidth: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            Spacer(minLength: 0)
        }
    }
    
    private func bubbleStateCard(title: String, systemImage: String, message: String) -> some View {
        EmptyStateCard(title: title, systemImage: systemImage, message: message)
    }
    
    private func startLocationUpdates() {
        if locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
        } else {
            locationManager.requestLocationPermission()
        }
    }
    
    private func isWithinNearbyRadius(_ post: CommunityPost) -> Bool {
        guard nearbyRadiusMiles > 0 else { return true }
        guard let origin = locationManager.location else { return true }
        guard let postLocation = location(for: post) else { return false }
        return origin.distance(from: postLocation) <= nearbyRadiusMiles * metersPerMile
    }
    
    private func location(for post: CommunityPost) -> CLLocation? {
        if let latitude = post.latitude, let longitude = post.longitude {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
        if let spotId = post.spotId,
           let spot = spotService.spots.first(where: { $0.id == spotId }) {
            return CLLocation(latitude: spot.latitude, longitude: spot.longitude)
        }
        return nil
    }
    
    private func startListening() {
        removeListener?()
        removeListener = communityService.listenToPosts(
            onUpdate: { updatedPosts in
                posts = updatedPosts
                loadError = nil
            },
            onError: { message in
                loadError = message
            }
        )
    }
}

struct SkateWithSafetyNote: View {
    var outlined: Bool = true
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.body.weight(.bold))
                .foregroundColor(.black)
            Text("Meet at a public spot. Don’t share your address. If someone feels off, report or block them.")
                .font(.caption.weight(.semibold))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(outlined ? 14 : 10)
        .frame(maxWidth: outlined ? 360 : .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: outlined ? 16 : 10, style: .continuous)
                .fill(Color.white.opacity(outlined ? 0.95 : 1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: outlined ? 16 : 10, style: .continuous)
                .stroke(Color.black, lineWidth: outlined ? 2.5 : 2)
        )
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct SessionPostMeta: View {
    let post: CommunityPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(post.formattedWhen, systemImage: "clock")
            if let whereText = post.displayWhere {
                Label(whereText, systemImage: "mappin.and.ellipse")
            }
            if let what = post.sessionWhat, !what.isEmpty {
                Text(what)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.12)))
            }
        }
        .font(.subheadline)
        .foregroundColor(.primary)
    }
}

struct SkateWithComposerView: View {
    var onSubmit: (String, Date, String, SkateSpot?, String?) async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotService = SpotService()
    @StateObject private var locationManager = LocationManager()
    @State private var sessionAt = SkateWithComposerView.defaultSessionTime()
    @State private var sessionWhat = "Street"
    @State private var selectedSpotId: String?
    @State private var locationText = ""
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @AppStorage("mapNearbyRadiusMiles") private var nearbyRadiusMiles: Double = 10
    
    private let metersPerMile = 1609.34
    
    private var nearbySpots: [SkateSpot] {
        guard nearbyRadiusMiles > 0, let origin = locationManager.location else {
            return spotService.spots
        }
        return spotService.spots.filter { spot in
            let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            return origin.distance(from: spotLocation) <= nearbyRadiusMiles * metersPerMile
        }
    }
    
    private var selectedSpot: SkateSpot? {
        spotService.spots.first { $0.id == selectedSpotId }
    }
    
    private var canPost: Bool {
        let hasPlace = selectedSpot != nil || !locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !sessionWhat.isEmpty && hasPlace && !isSubmitting
    }
    
    private let stickerBlue = Color(red: 0.18, green: 0.78, blue: 1.0)
    private let actionBlue = Color(red: 0.08, green: 0.32, blue: 0.78)
    private let inkMuted = Color.black.opacity(0.72)
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArtBackdrop(imageName: "PostsBackground", dim: 0.28, starBand: .header)
                
                ScrollView(.vertical, showsIndicators: false) {
                    StreetlineCard {
                        composerCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                StreetlineSheetHeader(title: "New session", closeDisabled: isSubmitting) {
                    dismiss()
                }
            }
            .task {
                if locationManager.authorizationStatus == .authorizedWhenInUse
                    || locationManager.authorizationStatus == .authorizedAlways {
                    locationManager.startLocationUpdates()
                } else {
                    locationManager.requestLocationPermission()
                }
                await spotService.fetchSpots()
            }
        }
    }
    
    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NEW SESSION")
                .font(.title3.weight(.heavy))
                .tracking(1)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("When")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.black)
                DatePicker(
                    "Session time",
                    selection: $sessionAt,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(actionBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 2)
                )
                Text("This hides 24 hours after the session time.")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(inkMuted)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Where")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.black)
                
                Menu {
                    Button("Type a place instead") {
                        selectedSpotId = nil
                    }
                    ForEach(nearbySpots) { spot in
                        Button(spot.name) {
                            selectedSpotId = spot.id
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedSpot?.name ?? "Type a place instead")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                
                if selectedSpotId == nil {
                    TextField("Place name", text: $locationText)
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black, lineWidth: 2)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("What")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.black)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(CommunityPost.sessionTypes, id: \.self) { type in
                        Button {
                            sessionWhat = type
                        } label: {
                            Text(type)
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(sessionWhat == type ? stickerBlue : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Details (optional)")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.black)
                TextField("Anything else", text: $details, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
            
            if let submitError {
                Text(submitError)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            
            SkateWithSafetyNote(outlined: false)
            
            Button {
                Task { await submit() }
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.subheadline.weight(.heavy))
                    }
                    Text(isSubmitting ? "POSTING..." : "POST")
                        .font(.subheadline.weight(.heavy))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(canPost ? actionBlue : Color.gray.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 2.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canPost)
            .padding(.top, 4)
        }
        .environment(\.colorScheme, .light)
    }
    
    private func submit() async {
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        do {
            try await onSubmit(details, sessionAt, sessionWhat, selectedSpot, locationText)
            dismiss()
        } catch {
            submitError = error.localizedDescription
        }
    }
    
    private static func defaultSessionTime() -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
    }
}

#Preview {
    NavigationView {
        CommunityForumView()
    }
}

