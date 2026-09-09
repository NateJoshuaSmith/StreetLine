//
//  NearbySkateShopsView.swift
//  Streetline
//
//  Nearby skate shops with directions in Apple Maps.
//

import SwiftUI

struct NearbySkateShopsView: View {
    let latitude: Double
    let longitude: Double
    var radiusMeters: Double = 10000
    
    var body: some View {
        NearbyPlacesListView(
            title: "Skate Shops",
            loadingText: "Finding skate shops nearby…",
            emptyTitle: "No skate shops nearby",
            emptyIcon: "storefront",
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            load: { lat, lng, radius in
                await GooglePlacesService().fetchNearbySkateShops(
                    latitude: lat,
                    longitude: lng,
                    radiusMeters: radius
                )
            }
        )
    }
}

#Preview {
    NearbySkateShopsView(latitude: 37.7749, longitude: -122.4194, radiusMeters: 10000)
}
