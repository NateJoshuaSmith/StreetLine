import SwiftUI
import MapKit
import CoreLocation
import UIKit
import FirebaseAuth

private enum NearbyPlaceKind {
    case shop
    case park
    
    var systemImage: String {
        switch self {
        case .shop: return "storefront.fill"
        case .park: return "figure.skateboarding"
        }
    }
    
    var color: Color {
        switch self {
        case .shop: return .orange
        case .park: return .green
        }
    }
}

private struct MapPlacePin: Identifiable, Equatable {
    let place: NearbyPlace
    let kind: NearbyPlaceKind
    
    var id: String { "\(kind)-\(place.id)" }
}

struct MapScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var activityService: ActivityService
    @StateObject private var spotService = SpotService()
    @StateObject private var userService = UserService()
    @StateObject private var locationManager = LocationManager()
    private let placesService = GooglePlacesService()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var showAddSpotSheet = false
    @State private var showSkateShopsSheet = false
    @State private var showSkateParksSheet = false
    @State private var showLocationSearch = false
    @State private var travelDestination: TravelDestination?
    @State private var nearbyShops: [NearbyPlace] = []
    @State private var nearbyParks: [NearbyPlace] = []
    @State private var selectedNearbyPlace: MapPlacePin?
    @State private var selectedLatitude: Double = 37.7749
    @State private var selectedLongitude: Double = -122.4194
    @State private var mapRegion: MKCoordinateRegion?
    @State private var mapProxy: MapProxy?
    @State private var draggingSpot: SkateSpot?
    @State private var dragOffset: CGSize = .zero
    @State private var mapViewSize: CGSize = .zero
    @State private var selectedSpot: SkateSpot? = nil
    @State private var selectedCalloutSpotId: String?
    /// Live aggregate for the map preview card (Firestore `ratings` subcollection).
    @State private var calloutRatingSummary: SpotService.SpotRatingSummary?
    @State private var isLoadingCalloutRating = false
    @State private var hasCenteredOnUserLocation = false
    @State private var shouldCenterOnUserWhenAvailable = false
    @State private var userCoordinateOverride: CLLocationCoordinate2D?
    @State private var recenterNonce = 0
    @State private var recenterToken = 0
    @State private var locationHelpMessage: String?
    @State private var isLoadingSpots = true
    /// After finishing a drag, ignore pin taps briefly so the callout doesn’t open from touch-up.
    @State private var suppressPinTapUntil: Date = .distantPast
    @State private var isTogglingCalloutFavorite = false
    @State private var streetViewTarget: StreetViewTarget?
    @State private var clipsSpot: SkateSpot?
    
    // Filters
    @State private var selectedTagFilter: String? = nil
    @State private var selectedDifficultyFilter: String? = nil
    @State private var selectedStatusFilter: String? = nil
    /// Miles from the user. `0` shows every spot.
    @AppStorage("mapNearbyRadiusMiles") private var nearbyRadiusMiles: Double = 10
    /// Miles for Google skate shops/parks. `0` is All (no mileage cutoff).
    @AppStorage("placesNearbyRadiusMiles") private var placesNearbyRadiusMiles: Double = 10
    
    private let allTags = ["Street", "Park", "DIY", "Ledge", "Rail", "Hubba", "Bowl", "Red Curb"]
    private let allDifficulties = ["Beginner", "Intermediate", "Advanced"]
    private let allFunLevels = ["Not fun but skateable", "Fun", "Super Fun"]
    private let nearbyRadiusChoices: [(label: String, miles: Double)] = [
        ("2 mi", 2),
        ("5 mi", 5),
        ("10 mi", 10),
        ("25 mi", 25),
        ("All", 0)
    ]
    private let metersPerMile = 1609.34
    /// About 1.5 miles across. The mile filter only hides pins; it does not change this.
    private let centerViewMeters: Double = 2_400
    
    private var nearbyRadiusLabel: String {
        nearbyRadiusMiles > 0 ? "\(Int(nearbyRadiusMiles)) mi" : "All"
    }
    
    private var resolvedUserCoordinate: CLLocationCoordinate2D? {
        validUserCoordinate() ?? userCoordinateOverride
    }
    
    private var placesSearchCoordinate: CLLocationCoordinate2D {
        if let travel = travelDestination {
            return travel.coordinate
        }
        return resolvedUserCoordinate
            ?? CLLocationCoordinate2D(latitude: selectedLatitude, longitude: selectedLongitude)
    }
    
    /// FILTER radius is measured from the travel destination, or GPS when you're not traveling.
    private var radiusOrigin: CLLocation? {
        if let travel = travelDestination {
            return CLLocation(latitude: travel.latitude, longitude: travel.longitude)
        }
        return locationManager.location
    }
    
    private var visibleMapPlaces: [MapPlacePin] {
        nearbyShops.map { MapPlacePin(place: $0, kind: .shop) }
            + nearbyParks.map { MapPlacePin(place: $0, kind: .park) }
    }
    
    private var nearbySearchRadiusMeters: Double {
        if placesNearbyRadiusMiles > 0 {
            return min(placesNearbyRadiusMiles * metersPerMile, 50_000)
        }
        return 50_000
    }
    
    private var filteredSpots: [SkateSpot] {
        spotService.spots.filter { spot in
            if let tag = selectedTagFilter {
                let tags = spot.tags ?? []
                if !tags.contains(tag) { return false }
            }
            if let diff = selectedDifficultyFilter {
                if spot.difficulty != diff { return false }
            }
            if let funLevel = selectedStatusFilter {
                if spot.status != funLevel { return false }
            }
            if nearbyRadiusMiles > 0, let origin = radiusOrigin {
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                if origin.distance(from: spotLocation) > nearbyRadiusMiles * metersPerMile {
                    return false
                }
            }
            return true
        }
    }
    
    // Render selected callout spot last so its annotation/card is always above other pins.
    private var orderedSpotsForRendering: [SkateSpot] {
        guard let selectedId = selectedCalloutSpotId else { return filteredSpots }
        return filteredSpots.sorted { lhs, rhs in
            let lhsSelected = lhs.id == selectedId
            let rhsSelected = rhs.id == selectedId
            if lhsSelected == rhsSelected { return false }
            return !lhsSelected && rhsSelected
        }
    }
    
    // Helper function to check if current user owns a spot
    private func isOwner(of spot: SkateSpot) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return spot.createdBy == currentUserId
    }
    
    // Helper function to determine pin color
    private func pinColor(for spot: SkateSpot) -> Color {
        if draggingSpot?.id == spot.id {
            return .orange  // Orange when dragging
        } else if isOwner(of: spot) {
            return .blue  // Blue if user owns it
        } else {
            return .red  // Red if someone else owns it
        }
    }
    
    private func pinAssetName(for _: SkateSpot) -> String {
        "SkateboardIcon"
    }
    
    private var userLocationDot: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.22))
                    .frame(width: 56, height: 56)
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
            Text("You")
                .font(.caption2.weight(.heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue))
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .allowsHitTesting(false)
        .accessibilityLabel("Your location")
    }
    
    private var travelPin: some View {
        VStack(spacing: 3) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color(red: 0.95, green: 0.28, blue: 0.18), .white)
                .overlay(
                    Circle().stroke(Color.black, lineWidth: 2)
                )
            Text("Here")
                .font(.caption2.weight(.heavy))
                .foregroundColor(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .allowsHitTesting(false)
        .accessibilityLabel("Travel destination")
    }

    // Loading indicator view
    private var loadingIndicator: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            Text("Loading spots...")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .zIndex(1)
    }
    
    
    // Long-press then drag to move your own spots (owner-only; Firestore rules should match).
    private func spotDragGesture(for spot: SkateSpot) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard isOwner(of: spot) else { return }
                
                switch value {
                case .second(true, let drag):
                    if draggingSpot == nil {
                        draggingSpot = spot
                        // Block touch-up from firing the pin button before drag `onEnded` runs.
                        suppressPinTapUntil = Date.distantFuture
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                    if let drag = drag {
                        dragOffset = drag.translation
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                guard isOwner(of: spot) else { return }
                let wasActivelyDragging = draggingSpot?.id == spot.id
                
                switch value {
                case .second(true, let drag):
                    if let drag = drag, let region = mapRegion {
                        let mapHeight = mapViewSize.height > 0 ? mapViewSize.height : 600.0
                        let mapWidth = mapViewSize.width > 0 ? mapViewSize.width : 400.0
                        
                        let latitudeDelta = -drag.translation.height * region.span.latitudeDelta / mapHeight
                        let longitudeDelta = drag.translation.width * region.span.longitudeDelta / mapWidth
                        
                        let newLatitude = spot.latitude + latitudeDelta
                        let newLongitude = spot.longitude + longitudeDelta
                        
                        Task {
                            do {
                                try await spotService.updateSpotLocation(
                                    spot,
                                    latitude: newLatitude,
                                    longitude: newLongitude
                                )
                            } catch {
                                print("Error updating spot location: \(error)")
                            }
                        }
                    }
                default:
                    break
                }
                
                draggingSpot = nil
                dragOffset = .zero
                
                // After a drag, ignore pin taps briefly so the preview doesn’t open from finger-up.
                suppressPinTapUntil = wasActivelyDragging
                    ? Date().addingTimeInterval(0.5)
                    : .distantPast
            }
    }
    
    // Handle pin taps: first tap shows callout, second tap opens details.
    private func handleSpotTap(_ spot: SkateSpot) {
        if Date() < suppressPinTapUntil {
            return
        }
        selectedNearbyPlace = nil
        if selectedCalloutSpotId == spot.id {
            selectedSpot = spot
        } else {
            selectedCalloutSpotId = spot.id
        }
    }
    
    /// Loads real ratings for the map callout (Firestore `ratings` subcollection).
    /// - Parameter showLoadingIndicator: `false` when refreshing after closing detail so the pill doesn’t flash “Loading…”.
    private func loadCalloutRating(for spotId: String, showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator {
            await MainActor.run { isLoadingCalloutRating = true }
        }
        do {
            let summary = try await spotService.fetchRatingSummary(spotId: spotId)
            await MainActor.run {
                guard selectedCalloutSpotId == spotId else { return }
                calloutRatingSummary = summary
                isLoadingCalloutRating = false
            }
        } catch {
            await MainActor.run {
                guard selectedCalloutSpotId == spotId else { return }
                calloutRatingSummary = nil
                isLoadingCalloutRating = false
            }
        }
    }
    
    private func openDirections(for spot: SkateSpot) {
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    @ViewBuilder
    private func pinContent(for spot: SkateSpot) -> some View {
        let ring = pinColor(for: spot)
        let asset = pinAssetName(for: spot)
        let selected = selectedCalloutSpotId == spot.id
        Button {
            handleSpotTap(spot)
        } label: {
            ZStack {
                // Same light blue / purple wash as Spot detail, Add spot, Skate shops, etc.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.2), radius: selected ? 6 : 3, x: 0, y: 2)
                Circle()
                    .stroke(ring, lineWidth: 3)
                    .frame(width: 44, height: 44)
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            }
            .scaleEffect(
                draggingSpot?.id == spot.id
                ? 1.2
                : (selected ? 1.12 : 1.0)
            )
            .shadow(
                color: selected ? Color.blue.opacity(0.35) : .clear,
                radius: selected ? 8 : 0,
                x: 0,
                y: 2
            )
            .offset(draggingSpot?.id == spot.id ? dragOffset : .zero)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func nearbyPlacePin(_ pin: MapPlacePin) -> some View {
        let selected = selectedNearbyPlace?.id == pin.id
        return Button {
            selectedCalloutSpotId = nil
            if selectedNearbyPlace?.id == pin.id {
                openDirections(for: pin.place)
            } else {
                selectedNearbyPlace = pin
            }
        } label: {
            Image(systemName: pin.kind.systemImage)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(pin.kind.color))
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                .scaleEffect(selected ? 1.12 : 1.0)
                .shadow(color: .black.opacity(0.25), radius: selected ? 5 : 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pin.place.name)
    }
    
    private func loadNearbyShops() async {
        let coord = placesSearchCoordinate
        let result = await placesService.fetchNearbySkateShops(
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusMeters: nearbySearchRadiusMeters
        )
        await MainActor.run { nearbyShops = result }
    }
    
    private func loadNearbyParks() async {
        let coord = placesSearchCoordinate
        let result = await placesService.fetchNearbySkateParks(
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusMeters: nearbySearchRadiusMeters
        )
        await MainActor.run { nearbyParks = result }
    }
    
    private func reloadVisibleNearbyPlaces() async {
        await loadNearbyShops()
        await loadNearbyParks()
    }
    
    private func openDirections(for place: NearbyPlace) {
        let item = MKMapItem(location: CLLocation(latitude: place.latitude, longitude: place.longitude), address: nil)
        item.name = place.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    @ViewBuilder
    private func calloutPreviewThumbnail(for spot: SkateSpot) -> some View {
        let size: CGFloat = 48
        Group {
            if let urlString = spot.primaryImageURLString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    case .failure:
                        Image(pinAssetName(for: spot))
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    case .empty:
                        ZStack {
                            Color(.systemGray6)
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    @unknown default:
                        Image(pinAssetName(for: spot))
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    }
                }
            } else {
                ApplePlacePhotoView(
                    coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                    width: size,
                    height: size,
                    cornerRadius: 10
                )
            }
        }
        .frame(width: size, height: size)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func calloutMiniCard(for spot: SkateSpot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                calloutPreviewThumbnail(for: spot)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        Text(spot.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        Button {
                            selectedCalloutSpotId = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if !spot.comment.isEmpty,
               spot.comment.caseInsensitiveCompare("No comment") != .orderedSame {
                Text(spot.comment)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 6) {
                Group {
                    if isLoadingCalloutRating {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.65)
                            Text("Loading…")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.08)))
                    } else if let s = calloutRatingSummary, s.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption2)
                            Text(String(format: "%.1f", s.average))
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.primary)
                            Text("(\(s.count))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.08)))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "star")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            Text("No ratings yet")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.08)))
                    }
                }
                
                if let tags = spot.tags, !tags.isEmpty {
                    ForEach(Array(tags.prefix(2)), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.blue.opacity(0.12)))
                    }
                }
            }
            
            HStack(spacing: 8) {
                if let difficulty = spot.difficulty, !difficulty.isEmpty {
                    Label(difficulty, systemImage: "speedometer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let status = spot.status, !status.isEmpty {
                    Label(status, systemImage: "face.smiling")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            CalloutClipsRow(spot: spot) {
                clipsSpot = spot
            }
            
            HStack(spacing: 8) {
                Button("Open") {
                    selectedSpot = spot
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Directions") {
                    openDirections(for: spot)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    streetViewTarget = StreetViewTarget(
                        name: spot.name,
                        latitude: spot.latitude,
                        longitude: spot.longitude
                    )
                } label: {
                    Image(systemName: "binoculars.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Street view")
                
                if Auth.auth().currentUser != nil, let spotId = spot.id {
                    Button {
                        Task { await toggleCalloutFavorite(spotId: spotId) }
                    } label: {
                        if isTogglingCalloutFavorite {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: userService.isFavorite(spotId: spotId) ? "heart.fill" : "heart")
                                .font(.body.weight(.semibold))
                                .foregroundColor(userService.isFavorite(spotId: spotId) ? .red : .secondary)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isTogglingCalloutFavorite)
                    .accessibilityLabel(userService.isFavorite(spotId: spotId) ? "Remove from favorites" : "Add to favorites")
                }
            }
            .padding(.top, 2)
        }
        .padding(10)
        .frame(width: 248, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func selectedCalloutOverlay(in geometry: GeometryProxy) -> some View {
        Group {
            if
                let selectedId = selectedCalloutSpotId,
                let spot = filteredSpots.first(where: { $0.id == selectedId }),
                let proxy = mapProxy,
                let point = proxy.convert(
                    CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                    to: .local
                )
            {
                // Keep the card in-bounds and above the selected pin.
                let halfWidth: CGFloat = 124
                let minX: CGFloat = halfWidth + 12
                let maxX: CGFloat = geometry.size.width - halfWidth - 12
                let x = min(max(point.x, minX), maxX)
                let y = max(110, point.y - 185)
                
                calloutMiniCard(for: spot)
                    .position(x: x, y: y)
                    .zIndex(300)
            } else {
                EmptyView()
            }
        }
    }
    
    private func nearbyPlaceCalloutOverlay(in geometry: GeometryProxy) -> some View {
        Group {
            if
                let pin = selectedNearbyPlace,
                let proxy = mapProxy,
                let point = proxy.convert(pin.place.coordinate, to: .local)
            {
                let halfWidth: CGFloat = 124
                let minX: CGFloat = halfWidth + 12
                let maxX: CGFloat = geometry.size.width - halfWidth - 12
                let x = min(max(point.x, minX), maxX)
                let y = max(110, point.y - 120)
                
                VStack(alignment: .leading, spacing: 6) {
                    Label(pin.place.name, systemImage: pin.kind.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    if let address = pin.place.formattedAddress, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Button {
                        openDirections(for: pin.place)
                    } label: {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.caption.weight(.semibold))
                    }
                }
                .padding(12)
                .frame(width: 240, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.96))
                        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .position(x: x, y: y)
                .zIndex(300)
            } else {
                EmptyView()
            }
        }
    }
    
    // Center indicator view
    private var centerIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 3)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .fill(Color.black)
                        .frame(width: 10, height: 10)
                }
                Spacer()
            }
            Spacer()
        }
    }
    
    // Map view with all its modifiers
    @ViewBuilder
    private func mapView(geometry: GeometryProxy, proxy: MapProxy) -> some View {
        Map(position: $cameraPosition) {
            if nearbyRadiusMiles > 0, let origin = radiusOrigin {
                MapCircle(center: origin.coordinate, radius: nearbyRadiusMiles * metersPerMile)
                    .foregroundStyle(Color.blue.opacity(0.08))
                    .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
            }
            ForEach(orderedSpotsForRendering) { spot in
                Annotation(spot.name, coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                    VStack(spacing: 6) {
                        if isOwner(of: spot) {
                            // Long-press (~0.35s) then drag. Simultaneous with tap so callout / open still work.
                            pinContent(for: spot)
                                .simultaneousGesture(spotDragGesture(for: spot))
                                .zIndex(1)
                        } else {
                            pinContent(for: spot)
                                .zIndex(1)
                        }
                    }
                    .zIndex(selectedCalloutSpotId == spot.id ? 1000 : 0)
                }
                .annotationTitles(.visible)
            }
            UserAnnotation {
                userLocationDot
            }
            if let travel = travelDestination {
                Annotation(travel.name, coordinate: travel.coordinate) {
                    travelPin
                }
            }
            ForEach(visibleMapPlaces) { pin in
                Annotation(pin.place.name, coordinate: pin.place.coordinate) {
                    nearbyPlacePin(pin)
                }
                .annotationTitles(.visible)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .onMapCameraChange(frequency: .continuous) { context in
            let newRegion = context.region
            mapRegion = newRegion
            selectedLatitude = newRegion.center.latitude
            selectedLongitude = newRegion.center.longitude
        }
        .ignoresSafeArea()
        .onAppear {
            mapProxy = proxy
            mapViewSize = geometry.size
            let initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapRegion = initialRegion
            selectedLatitude = initialRegion.center.latitude
            selectedLongitude = initialRegion.center.longitude
        }
        .onChange(of: geometry.size) { oldSize, newSize in
            mapViewSize = newSize
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    // Faster tap-out: dismiss on any map tap event.
                    if selectedCalloutSpotId != nil {
                        selectedCalloutSpotId = nil
                    }
                    if selectedNearbyPlace != nil {
                        selectedNearbyPlace = nil
                    }
                }
        )
    }
    
    // Main map content
    @ViewBuilder
    private func mapContent(geometry: GeometryProxy) -> some View {
        ZStack {
            if isLoadingSpots {
                loadingIndicator
            }
            
            MapReader { proxy in
                mapView(geometry: geometry, proxy: proxy)
            }
            .background {
                MapKitRecenterHook(
                    token: recenterToken,
                    fallbackCoordinate: validUserCoordinate(),
                    viewMeters: centerViewMeters
                )
            }
            
            selectedCalloutOverlay(in: geometry)
            nearbyPlaceCalloutOverlay(in: geometry)
            
            centerIndicator
                .allowsHitTesting(false)
            
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Button(action: { dismiss() }) {
                        mapToolbarIcon("chevron.left")
                    }
                    
                    filterBarCompact
                    
                    Button(action: {
                        if let region = mapRegion {
                            selectedLatitude = region.center.latitude
                            selectedLongitude = region.center.longitude
                        }
                        showAddSpotSheet = true
                    }) {
                        mapToolbarIcon("plus")
                    }
                }
                .padding(.horizontal, 12)
                
                HStack(spacing: 6) {
                    NavigationLink(destination: FriendsListView()) {
                        HStack(spacing: 4) {
                            mapToolbarIcon("person.2.fill")
                            if activityService.homeBadgeCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    Button(action: { showSkateShopsSheet = true }) {
                        mapToolbarIcon("storefront.fill", color: .orange)
                    }
                    
                    Button(action: { showSkateParksSheet = true }) {
                        mapToolbarIcon("figure.skateboarding", color: .green)
                    }
                    
                    NavigationLink(destination: FavoritesListView()) {
                        mapToolbarIcon("heart.fill", color: .pink)
                    }
                }
                
                Spacer()
                    .allowsHitTesting(false)
                
                if let travel = travelDestination {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption.weight(.heavy))
                            Text(travel.name)
                                .font(.caption.weight(.heavy))
                                .lineLimit(1)
                            Button {
                                clearTravelAndReturnHome()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.heavy))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Leave \(travel.name)")
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(toolbarCapsule)
                    }
                    .padding(.horizontal, 14)
                }
                
                HStack {
                    Button(action: { showLocationSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(toolbarCapsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search a location to travel to")
                    
                    Spacer()
                        .allowsHitTesting(false)
                    Button(action: centerOnUserLocation) {
                        Image(systemName: "location.fill")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(toolbarCapsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Center on my location")
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 28)
            }
            .padding(.top, 4)
            .zIndex(90)
            
        }
    }
    
    private var filterBarCompact: some View {
        VStack(spacing: 4) {
            Text("FILTER")
                .font(.caption.weight(.heavy))
                .tracking(0.8)
                .foregroundColor(.primary)
            
            HStack(spacing: 6) {
                Menu {
                    Button("All tags") { selectedTagFilter = nil }
                    ForEach(allTags, id: \.self) { tag in
                        Button(tag) { selectedTagFilter = tag }
                    }
                } label: {
                    Label(selectedTagFilter ?? "Tags", systemImage: "tag")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(selectedTagFilter == nil ? .primary : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                selectedTagFilter == nil
                                    ? Color(.systemGray5)
                                    : Color.blue.opacity(0.18)
                            )
                        )
                        .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                }
                Menu {
                    Button("Any level") { selectedDifficultyFilter = nil }
                    ForEach(allDifficulties, id: \.self) { level in
                        Button(level) { selectedDifficultyFilter = level }
                    }
                } label: {
                    Label(selectedDifficultyFilter ?? "Difficulty", systemImage: "speedometer")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(selectedDifficultyFilter == nil ? .primary : .purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                selectedDifficultyFilter == nil
                                    ? Color(.systemGray5)
                                    : Color.purple.opacity(0.18)
                            )
                        )
                        .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                }
                Menu {
                    Button("Any fun") { selectedStatusFilter = nil }
                    ForEach(allFunLevels, id: \.self) { level in
                        Button(level) { selectedStatusFilter = level }
                    }
                } label: {
                    Label(selectedStatusFilter ?? "Fun", systemImage: "face.smiling")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(selectedStatusFilter == nil ? .primary : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                selectedStatusFilter == nil
                                    ? Color(.systemGray5)
                                    : Color.green.opacity(0.18)
                            )
                        )
                        .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                }
            }
            
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
                    .font(.caption2.weight(.medium))
                    .foregroundColor(nearbyRadiusMiles > 0 ? .orange : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule().fill(
                            nearbyRadiusMiles > 0
                                ? Color.orange.opacity(0.18)
                                : Color(.systemGray5)
                        )
                    )
                    .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                // Solid light blue bubble background (not transparent, but soft)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.86, green: 0.93, blue: 1.0),  // light blue
                            Color(red: 0.91, green: 0.88, blue: 1.0)   // light bluish-purple
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black, lineWidth: 1.5)
                )
        )
    }
    
    private func mapToolbarIcon(_ systemName: String, color: Color = .primary, isOn: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.caption.weight(.semibold))
            .foregroundColor(isOn ? color : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    Capsule().fill(isOn ? color.opacity(0.22) : Color.white.opacity(0.92))
                    Capsule().strokeBorder(Color.black, lineWidth: 2.5)
                }
            )
            .padding(2)
    }
    
    private var toolbarCapsule: some View {
        ZStack {
            Capsule().fill(Color.white.opacity(0.92))
            Capsule().strokeBorder(Color.black, lineWidth: 2.5)
        }
    }
    
    private func toggleCalloutFavorite(spotId: String) async {
        isTogglingCalloutFavorite = true
        defer { isTogglingCalloutFavorite = false }
        do {
            if userService.isFavorite(spotId: spotId) {
                try await userService.removeFavorite(spotId: spotId)
            } else {
                try await userService.addFavorite(spotId: spotId)
            }
        } catch {
            print("Error updating favorite: \(error)")
        }
    }
    
    // Setup task logic
    private func setupTask() {
        spotService.listenToSpots()
        Task { await userService.loadFavorites() }
        Task { await reloadVisibleNearbyPlaces() }
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
            if let userLocation = locationManager.location, !hasCenteredOnUserLocation,
               isValidCoordinate(userLocation.coordinate) {
                userCoordinateOverride = userLocation.coordinate
                hasCenteredOnUserLocation = true
                recenterToken += 1
            }
        } else {
            locationManager.requestLocationPermission()
        }
    }
    
    // Handle authorization status change
    private func handleAuthorizationChange(newStatus: CLAuthorizationStatus) {
        if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
        }
    }
    
    // Handle spots change
    private func handleSpotsChange(newSpots: [SkateSpot]) {
        if !newSpots.isEmpty && isLoadingSpots {
            isLoadingSpots = false
        }
    }
    
    // Handle location change
    private func handleLocationChange(newLocation: CLLocation?) {
        guard let userLocation = newLocation, isValidCoordinate(userLocation.coordinate) else { return }
        userCoordinateOverride = userLocation.coordinate
        guard travelDestination == nil else { return }
        guard !hasCenteredOnUserLocation || shouldCenterOnUserWhenAvailable else { return }
        hasCenteredOnUserLocation = true
        shouldCenterOnUserWhenAvailable = false
        recenterToken += 1
        Task { await reloadVisibleNearbyPlaces() }
    }
    
    private func applyNearbyCamera(to coordinate: CLLocationCoordinate2D) {
        moveCamera(to: coordinate)
    }
    
    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        recenterNonce += 1
        // Each tap needs a slightly different region or SwiftUI Map ignores the update.
        let meters = centerViewMeters + Double(recenterNonce)
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: meters,
            longitudinalMeters: meters
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(region)
        }
    }
    
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 && (lat != 0 || lon != 0)
    }
    
    private func validUserCoordinate() -> CLLocationCoordinate2D? {
        if let coordinate = locationManager.location?.coordinate, isValidCoordinate(coordinate) {
            return coordinate
        }
        if let coordinate = userCoordinateOverride, isValidCoordinate(coordinate) {
            return coordinate
        }
        return nil
    }
    
    private func travelTo(_ destination: TravelDestination) {
        travelDestination = destination
        hasCenteredOnUserLocation = true
        shouldCenterOnUserWhenAvailable = false
        moveCamera(to: destination.coordinate)
        Task { await reloadVisibleNearbyPlaces() }
    }
    
    private func clearTravelAndReturnHome() {
        centerOnUserLocation()
    }
    
    private func centerOnUserLocation() {
        let leavingTravel = travelDestination != nil
        travelDestination = nil
        if leavingTravel {
            Task { await reloadVisibleNearbyPlaces() }
        }
        
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            locationHelpMessage = "Location is turned off for Streetline. Turn it on in Settings, then tap the blue arrow again."
            return
        case .notDetermined:
            locationManager.requestLocationPermission()
            shouldCenterOnUserWhenAvailable = true
            return
        default:
            locationManager.startLocationUpdates()
        }
        
        if let coordinate = validUserCoordinate() {
            userCoordinateOverride = coordinate
            hasCenteredOnUserLocation = true
            shouldCenterOnUserWhenAvailable = false
            moveCamera(to: coordinate)
            recenterToken += 1
            return
        }
        
        shouldCenterOnUserWhenAvailable = true
        recenterToken += 1
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard validUserCoordinate() == nil else { return }
            await MainActor.run {
                locationHelpMessage = "Can't find your GPS yet. On a phone: Settings → Streetline → Location → While Using. In Simulator: Features → Location → Apple."
            }
        }
    }
    
    private func regionForNearbyRadius(around coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let miles = nearbyRadiusMiles > 0 ? nearbyRadiusMiles : 10
        let meters = miles * metersPerMile
        let latDelta = max((meters * 2.3) / 111_000.0, 0.012)
        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: latDelta)
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            mapContent(geometry: geometry)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddSpotSheet) {
            AddSpotView(
                spotService: spotService,
                latitude: selectedLatitude,
                longitude: selectedLongitude
            )
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot, spotService: spotService)
                .onDisappear {
                    Task { await userService.loadFavorites() }
                }
        }
        .sheet(isPresented: $showSkateShopsSheet) {
            NearbySkateShopsView(
                latitude: placesSearchCoordinate.latitude,
                longitude: placesSearchCoordinate.longitude
            )
        }
        .sheet(isPresented: $showSkateParksSheet) {
            NearbySkateParksView(
                latitude: placesSearchCoordinate.latitude,
                longitude: placesSearchCoordinate.longitude
            )
        }
        .sheet(isPresented: $showLocationSearch) {
            MapLocationSearchView { destination in
                travelTo(destination)
            }
        }
        .sheet(item: $streetViewTarget) { target in
            StreetViewSheet(coordinate: target.coordinate, title: target.name)
        }
        .sheet(item: $clipsSpot) { spot in
            SpotClipsView(spot: spot)
        }
        .alert(
            "Location needed",
            isPresented: Binding(
                get: { locationHelpMessage != nil },
                set: { if !$0 { locationHelpMessage = nil } }
            )
        ) {
            if locationManager.authorizationStatus == .denied
                || locationManager.authorizationStatus == .restricted {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button("OK", role: .cancel) {
                locationHelpMessage = nil
            }
        } message: {
            Text(locationHelpMessage ?? "")
        }
        .task {
            setupTask()
        }
        .onChange(of: locationManager.authorizationStatus) { oldStatus, newStatus in
            handleAuthorizationChange(newStatus: newStatus)
        }
        .onChange(of: spotService.spots) { oldSpots, newSpots in
            handleSpotsChange(newSpots: newSpots)
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            handleLocationChange(newLocation: newLocation)
        }
        .onChange(of: nearbyRadiusMiles) { _, _ in
            if let selectedId = selectedCalloutSpotId,
               !filteredSpots.contains(where: { $0.id == selectedId }) {
                selectedCalloutSpotId = nil
            }
        }
        .onChange(of: placesNearbyRadiusMiles) { _, _ in
            Task { await reloadVisibleNearbyPlaces() }
        }
        .onChange(of: selectedCalloutSpotId) { _, newId in
            if let id = newId {
                calloutRatingSummary = nil
                Task { await loadCalloutRating(for: id, showLoadingIndicator: true) }
            } else {
                calloutRatingSummary = nil
                isLoadingCalloutRating = false
            }
        }
        .onChange(of: selectedSpot) { _, newSpot in
            // After rating in detail, refresh the preview so the average updates.
            if newSpot == nil, let id = selectedCalloutSpotId {
                Task { await loadCalloutRating(for: id, showLoadingIndicator: false) }
            }
        }
    }
}

private struct MapKitRecenterHook: UIViewRepresentable {
    let token: Int
    let fallbackCoordinate: CLLocationCoordinate2D?
    let viewMeters: CLLocationDistance
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard token > 0, token != context.coordinator.lastToken else { return }
        context.coordinator.lastToken = token
        
        func recenter() {
            let mapView = uiView.window?.streetline_findMapView() ?? UIView.streetline_firstMapView()
            guard let mapView else { return }
            mapView.showsUserLocation = true
            let coordinate = mapView.userLocation.location?.coordinate ?? fallbackCoordinate
            if let coordinate, CLLocationCoordinate2DIsValid(coordinate),
               abs(coordinate.latitude) > 0.0001 || abs(coordinate.longitude) > 0.0001 {
                mapView.setUserTrackingMode(.none, animated: false)
                mapView.setRegion(
                    MKCoordinateRegion(
                        center: coordinate,
                        latitudinalMeters: viewMeters,
                        longitudinalMeters: viewMeters
                    ),
                    animated: true
                )
            } else {
                mapView.setUserTrackingMode(.follow, animated: true)
            }
        }
        
        DispatchQueue.main.async {
            recenter()
            if uiView.window?.streetline_findMapView() == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: recenter)
            }
        }
    }
    
    final class Coordinator {
        var lastToken = 0
    }
}

private extension UIView {
    func streetline_findMapView() -> MKMapView? {
        if let mapView = self as? MKMapView {
            return mapView
        }
        for child in subviews {
            if let mapView = child.streetline_findMapView() {
                return mapView
            }
        }
        return nil
    }
    
    static func streetline_firstMapView() -> MKMapView? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if let mapView = window.streetline_findMapView() {
                    return mapView
                }
            }
        }
        return nil
    }
}

#Preview {
    MapScreen()
        .environmentObject(ActivityService())
}