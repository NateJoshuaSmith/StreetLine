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
    
    var body: some View {
        NearbyPlacesListView(
            title: "Shops",
            loadingText: "Finding shops nearby…",
            emptyTitle: "No shops nearby",
            emptyIcon: "storefront",
            latitude: latitude,
            longitude: longitude,
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
    NearbySkateShopsView(latitude: 37.7749, longitude: -122.4194)
}
