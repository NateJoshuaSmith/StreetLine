//
//  LocationSearchCompleter.swift
//  Streetline
//
//  Apple Maps autocomplete for jumping the map to a city or place.
//

import Foundation
import MapKit
import Combine

final class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                results = []
                errorMessage = nil
                completer.queryFragment = ""
            } else {
                completer.queryFragment = trimmed
            }
        }
    }
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var errorMessage: String?
    @Published var isResolving = false
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
            self.errorMessage = nil
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.results = []
            self.errorMessage = error.localizedDescription
        }
    }
    
    func resolve(_ completion: MKLocalSearchCompletion) async -> TravelDestination? {
        await resolve(MKLocalSearch.Request(completion: completion), fallbackName: completion.title)
    }
    
    func resolveTypedQuery() async -> TravelDestination? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]
        return await resolve(request, fallbackName: trimmed)
    }
    
    private func resolve(_ request: MKLocalSearch.Request, fallbackName: String) async -> TravelDestination? {
        await MainActor.run { isResolving = true }
        defer {
            Task { @MainActor in isResolving = false }
        }
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                await MainActor.run { errorMessage = "No matching place found." }
                return nil
            }
            let coordinate = item.location.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate) else {
                await MainActor.run { errorMessage = "That place has no map location." }
                return nil
            }
            let name = (item.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? fallbackName
            return TravelDestination(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return nil
        }
    }
}

struct TravelDestination: Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
