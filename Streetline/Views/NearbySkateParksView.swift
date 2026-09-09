//
//  NearbySkateParksView.swift
//  Streetline
//
//  Nearby skate parks with directions in Apple Maps.
//

import SwiftUI

struct NearbySkateParksView: View {
    let latitude: Double
    let longitude: Double
    
    var body: some View {
        NearbyPlacesListView(
            title: "Skate Parks",
            loadingText: "Finding skate parks nearby…",
            emptyTitle: "No skate parks nearby",
            emptyIcon: "figure.skateboarding",
            latitude: latitude,
            longitude: longitude,
            load: { lat, lng, radius in
                await GooglePlacesService().fetchNearbySkateParks(
                    latitude: lat,
                    longitude: lng,
                    radiusMeters: radius
                )
            }
        )
    }
}

#Preview {
    NearbySkateParksView(latitude: 37.7749, longitude: -122.4194)
}
