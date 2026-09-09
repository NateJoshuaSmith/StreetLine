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
    var load: (_ latitude: Double, _ longitude: Double, _ radiusMeters: Double) async -> [NearbyPlace]
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage("placesNearbyRadiusMiles") private var placesRadiusMiles: Double = 10
    @State private var places: [NearbyPlace] = []
    @State private var isLoading = true
    
    private let metersPerMile = 1609.34
    private let stickerBlue = Color(red: 0.18, green: 0.78, blue: 1.0)
    private let radiusChoices: [(label: String, miles: Double)] = [
        ("2 mi", 2),
        ("5 mi", 5),
        ("10 mi", 10),
        ("25 mi", 25),
        ("All", 0)
    ]
    
    private var origin: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    private var includeMileage: Bool {
        placesRadiusMiles > 0
    }
    
    /// Google Places caps location bias at 50 km. `0` means All.
    private var searchRadiusMeters: Double {
        if placesRadiusMiles > 0 {
            return min(placesRadiusMiles * metersPerMile, 50_000)
        }
        return 50_000
    }
    
    private var emptyMessage: String {
        if includeMileage {
            let miles = max(1, Int(placesRadiusMiles.rounded()))
            return "Nothing turned up within \(miles) miles of you. Try All to see every listing nearby."
        }
        return "Google didn’t find any nearby."
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
                            message: emptyMessage
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(places) { place in
                                    StreetlineCard {
                                        NearbyPlaceCard(
                                            place: place,
                                            origin: origin,
                                            showMileage: includeMileage
                                        )
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
                VStack(spacing: 10) {
                    StreetlineSheetHeader(title: title, onClose: { dismiss() })
                    radiusPicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            }
            .task(id: searchRadiusMeters) {
                isLoading = true
                let result = await load(latitude, longitude, searchRadiusMeters)
                let nearby = result.filter { place in
                    origin.distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
                        <= searchRadiusMeters
                }
                await MainActor.run {
                    places = nearby
                    isLoading = false
                }
            }
        }
    }
    
    private var radiusPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(radiusChoices, id: \.miles) { choice in
                    let isOn = placesRadiusMiles == choice.miles
                    Button {
                        placesRadiusMiles = choice.miles
                    } label: {
                        Text(choice.label.uppercased())
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isOn ? stickerBlue : Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.black, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.miles == 0 ? "All distances" : choice.label)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}

private struct NearbyPlaceCard: View {
    let place: NearbyPlace
    let origin: CLLocation
    var showMileage: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(place.name)
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.black)
                Spacer()
                if showMileage {
                    Text(distanceText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black.opacity(0.72))
                }
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
