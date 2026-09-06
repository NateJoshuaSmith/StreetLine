//
//  NearbySkateParksView.swift
//  SpotFinder
//
//  Shows skate parks near the map area. Opens directions in Apple Maps.
//

import SwiftUI
import MapKit
import CoreLocation

struct NearbySkateParksView: View {
    let latitude: Double
    let longitude: Double
    var radiusMeters: Double = 10000
    
    @Environment(\.dismiss) var dismiss
    
    // Google Places skate parks
    @State private var places: [NearbyPlace] = []
    @State private var isLoadingParks = true
    
    // User-created pins
    @State private var userSpots: [SkateSpot] = []
    @State private var isLoadingUserSpots = true
    
    // Tab selection between parks vs user pins
    private enum ParksTab: String, CaseIterable, Identifiable {
        case parks = "Skate Parks"
        case userPins = "User Pins"
        
        var id: String { rawValue }
    }
    @State private var selectedTab: ParksTab = .parks
    
    private let placesService = GooglePlacesService()
    private let spotService = SpotService()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Light blue gradient background (no dark overlay)
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Picker("Nearby type", selection: $selectedTab) {
                        ForEach(ParksTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    Group {
                        switch selectedTab {
                        case .parks:
                            if isLoadingParks {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Finding skate parks nearby…")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if places.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "sportscourt")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                    Text("No skate parks found in this area")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                List(places) { place in
                                    SkateParkRow(place: place)
                                }
                                .scrollContentBackground(.hidden)
                            }
                            
                        case .userPins:
                            if isLoadingUserSpots {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Finding user pins nearby…")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if userSpots.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                    Text("No user pins found in this area")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                List(userSpots) { spot in
                                    UserSpotRow(spot: spot)
                                }
                                .scrollContentBackground(.hidden)
                            }
                        }
                    }
                }
            }
            .navigationTitle("") // custom styled title bubble like Settings
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Skate Parks & User Pins Nearby")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.95)) // brighter bubble
                        )
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadParks()
                await loadUserSpots()
            }
        }
    }
    
    private func loadParks() async {
        isLoadingParks = true
        let result = await placesService.fetchNearbySkateParks(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
        await MainActor.run {
            places = result
            isLoadingParks = false
        }
    }
    
    private func loadUserSpots() async {
        isLoadingUserSpots = true
        await spotService.fetchSpots()
        
        let center = CLLocation(latitude: latitude, longitude: longitude)
        let allSpots = spotService.spots
        
        let nearby = allSpots.filter { spot in
            let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            let distance = spotLocation.distance(from: center) // meters
            return distance <= radiusMeters
        }
        
        await MainActor.run {
            userSpots = nearby
            isLoadingUserSpots = false
        }
    }
}

// MARK: - Row with name, address, and Directions button
private struct SkateParkRow: View {
    let place: NearbyPlace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(place.name)
                .font(.headline)
                .foregroundColor(.primary)
            if let address = place.formattedAddress, !address.isEmpty {
                Text(address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Button(action: openInMaps) {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
    
    private func openInMaps() {
        let location = CLLocation(latitude: place.coordinate.latitude,
                                  longitude: place.coordinate.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Row for user-created spots
private struct UserSpotRow: View {
    let spot: SkateSpot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(spot.name)
                .font(.headline)
                .foregroundColor(.primary)
            if !spot.comment.isEmpty {
                Text(spot.comment)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Button(action: openInMaps) {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
    
    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

#Preview {
    NearbySkateParksView(latitude: 37.7749, longitude: -122.4194, radiusMeters: 10000)
}
