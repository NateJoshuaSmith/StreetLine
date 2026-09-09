//
//  NearbyPlacesListView.swift
//  Streetline
//

import SwiftUI
import MapKit
import CoreLocation

struct NearbyPlacesListView: View {
    let title: String
    let loadingText: String
    let emptyTitle: String
    let emptyIcon: String
    let latitude: Double
    let longitude: Double
    var radiusMeters: Double = 10000
    var load: (_ latitude: Double, _ longitude: Double, _ radiusMeters: Double) async -> [NearbyPlace]
    
    @Environment(\.dismiss) private var dismiss
    @State private var places: [NearbyPlace] = []
    @State private var isLoading = true
    
    private var origin: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    private var radiusLabel: String {
        let miles = radiusMeters / 1609.34
        if miles >= 30 {
            return "about \(Int(miles.rounded())) miles"
        }
        return "\(max(1, Int(miles.rounded()))) miles"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArtBackdrop(imageName: "CityImage", dim: 0.22, starBand: .header)
                
                Group {
                    if isLoading {
                        StreetlineCard {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(.black)
                                Text(loadingText)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 20)
                    } else if places.isEmpty {
                        EmptyStateCard(
                            title: emptyTitle,
                            systemImage: emptyIcon,
                            message: "Nothing turned up within \(radiusLabel) of you."
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(places) { place in
                                    StreetlineCard {
                                        NearbyPlaceCard(place: place, origin: origin)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                StreetlineSheetHeader(title: title, onClose: { dismiss() })
            }
            .task {
                isLoading = true
                let result = await load(latitude, longitude, radiusMeters)
                await MainActor.run {
                    places = result
                    isLoading = false
                }
            }
        }
    }
}

private struct NearbyPlaceCard: View {
    let place: NearbyPlace
    let origin: CLLocation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(place.name)
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.black)
                Spacer()
                Text(distanceText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black.opacity(0.72))
            }
            if let address = place.formattedAddress, !address.isEmpty {
                Text(address)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.black.opacity(0.72))
            }
            Button(action: openInMaps) {
                StreetlineStickerButton(
                    title: "DIRECTIONS",
                    systemImage: "arrow.triangle.turn.up.right.diamond.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var distanceText: String {
        let miles = origin.distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude)) / 1609.34
        if miles < 0.1 { return "Nearby" }
        return String(format: "%.1f mi", miles)
    }
    
    private func openInMaps() {
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
