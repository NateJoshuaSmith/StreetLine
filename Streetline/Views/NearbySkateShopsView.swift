//
//  NearbySkateShopsView.swift
//  SpotFinder
//
//  Shows skate shops near the map area. Opens directions in Apple Maps.
//

import SwiftUI
import MapKit

struct NearbySkateShopsView: View {
    let latitude: Double
    let longitude: Double
    var radiusMeters: Double = 10000
    
    @Environment(\.dismiss) var dismiss
    @State private var places: [NearbyPlace] = []
    @State private var isLoading = true
    
    private let placesService = GooglePlacesService()
    
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
                
                Group {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Finding skate shops nearby…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if places.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "storefront")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No skate shops found in this area")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(places) { place in
                            SkateShopRow(place: place)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("") // custom styled title bubble like Settings
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Skate Shops Nearby")
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
                await loadShops()
            }
        }
    }
    
    private func loadShops() async {
        isLoading = true
        let result = await placesService.fetchNearbySkateShops(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
        await MainActor.run {
            places = result
            isLoading = false
        }
    }
}

// MARK: - Row with name, address, and Directions button
private struct SkateShopRow: View {
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

#Preview {
    NearbySkateShopsView(latitude: 37.7749, longitude: -122.4194, radiusMeters: 10000)
}

