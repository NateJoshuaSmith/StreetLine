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
    
    @State private var places: [NearbyPlace] = []
    @State private var isLoadingParks = true
    
    private let placesService = GooglePlacesService()
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                Group {
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
                        EmptyStateCard(
                            title: "No skate parks nearby",
                            systemImage: "sportscourt",
                            message: "Try moving the map to another area."
                        )
                    } else {
                        List(places) { place in
                            SkateParkRow(place: place)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Skate Parks Nearby")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.95))
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
}

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

#Preview {
    NearbySkateParksView(latitude: 37.7749, longitude: -122.4194, radiusMeters: 10000)
}
