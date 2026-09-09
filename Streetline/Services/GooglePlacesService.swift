//
//  GooglePlacesService.swift
//  SpotFinder
//
//  Fetches place photo URL from Google Places API (New) for a spot's location.
//  Add your API key in Secrets.xcconfig (GOOGLE_PLACES_API_KEY). It is injected into Info.plist at build time.
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Nearby place (e.g. skate shop) for list + directions
struct NearbyPlace: Identifiable, Equatable {
    let id: String
    let name: String
    let formattedAddress: String?
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct GooglePlacesService {
    
    /// Read from Info.plist (filled from Secrets.xcconfig). Restrict the key to Places API + this iOS bundle ID.
    private static var apiKey: String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String
        if let raw, !raw.isEmpty {
            print("[PlacesNew] Loaded API key from Info.plist (length: \(raw.count))")
        } else {
            print("[PlacesNew] GooglePlacesAPIKey missing or empty in target Info")
        }
        return raw
    }
    
    /// iOS-restricted keys require this header on REST calls. Without it Google returns 403
    /// "Requests from this iOS client application <empty> are blocked."
    private static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Streetline.Streetline"
    }
    
    /// Finds a nearby place and returns the first photo URL, or nil if none found / no API key.
    /// Uses Places API (New): places.searchText -> photo resource name -> place photos media.
    func fetchPlacePhotoURL(latitude: Double, longitude: Double, spotName: String) async -> URL? {
        guard let key = Self.apiKey, !key.isEmpty else {
            print("[PlacesNew] Aborting fetchPlacePhotoURL – no API key")
            return nil
        }
        
        print("[PlacesNew] Fetching place photo for \"\(spotName)\" at (\(latitude), \(longitude))")
        
        // 1) Text search (New) to find a place with at least one photo near the spot.
        guard let photoName = await findFirstPhotoResourceName(latitude: latitude,
                                                               longitude: longitude,
                                                               query: spotName,
                                                               apiKey: key) else {
            print("[PlacesNew] No photo resource name found for spot")
            return nil
        }
        print("[PlacesNew] Found photo resource name: \(photoName)")
        
        // 2) Call Place Photos (New) media endpoint with skipHttpRedirect to get a stable photoUri.
        guard let photoURL = await fetchPhotoURI(photoName: photoName, apiKey: key) else {
            print("[PlacesNew] Failed to fetch photoUri for \(photoName)")
            return nil
        }
        print("[PlacesNew] Final photo URL: \(photoURL)")
        return photoURL
    }
    
    /// Search for skate shops near the given coordinate.
    func fetchNearbySkateShops(latitude: Double, longitude: Double, radiusMeters: Double = 10000) async -> [NearbyPlace] {
        await fetchNearbyPlaces(
            query: "skate shop",
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            include: NearbyPlaceRules.isSkateShop
        )
    }
    
    /// Search for skate parks near the given coordinate.
    func fetchNearbySkateParks(latitude: Double, longitude: Double, radiusMeters: Double = 10000) async -> [NearbyPlace] {
        await fetchNearbyPlaces(
            query: "skate park",
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            include: NearbyPlaceRules.isSkatePark
        )
    }
    
    private func fetchNearbyPlaces(
        query: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        include: (NearbyPlace) -> Bool
    ) async -> [NearbyPlace] {
        let google = await searchTextPlaces(
            query: query,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
        let googleFiltered = NearbyPlaceRules.placesWithinRadius(
            google.filter(include),
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
        if !googleFiltered.isEmpty {
            print("[PlacesNew] \(query): \(googleFiltered.count) Google results inside \(Int(radiusMeters))m")
            return googleFiltered
        }
        let apple = await mapKitPlaces(
            query: query,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
        let appleFiltered = NearbyPlaceRules.placesWithinRadius(
            apple.filter(include),
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
        print("[PlacesNew] \(query): Google empty/filtered, Apple Maps fallback \(appleFiltered.count) inside \(Int(radiusMeters))m")
        return appleFiltered
    }
    
    private func searchTextPlaces(
        query: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    ) async -> [NearbyPlace] {
        guard let key = Self.apiKey, !key.isEmpty else {
            print("[PlacesNew] Aborting searchText (\(query)) – no API key")
            return []
        }
        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText") else { return [] }
        
        var request = placesPOSTRequest(
            url: url,
            apiKey: key,
            fieldMask: "places.id,places.displayName,places.formattedAddress,places.location"
        )
        let clampedRadius = min(max(radiusMeters, 1), 50_000)
        let latDelta = clampedRadius / 111_320.0
        let lngDelta = clampedRadius / (111_320.0 * max(cos(latitude * .pi / 180), 0.01))
        let body: [String: Any] = [
            "textQuery": query,
            "rankPreference": "DISTANCE",
            "locationRestriction": [
                "rectangle": [
                    "low": [
                        "latitude": latitude - latDelta,
                        "longitude": longitude - lngDelta
                    ],
                    "high": [
                        "latitude": latitude + latDelta,
                        "longitude": longitude + lngDelta
                    ]
                ]
            ],
            "maxResultCount": 20
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("[PlacesNew] Failed to encode \(query) search body: \(error.localizedDescription)")
            return []
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[PlacesNew] searchText (\(query)) HTTP status: \(http.statusCode)")
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            if let error = json["error"] as? [String: Any] {
                print("[PlacesNew] searchText (\(query)) error: \(error["status"] ?? "") \(error["message"] ?? "")")
                return []
            }
            guard let places = json["places"] as? [[String: Any]] else {
                return []
            }
            return places.compactMap { nearbyPlace(from: $0) }
        } catch {
            print("[PlacesNew] searchText (\(query)) error: \(error.localizedDescription)")
            return []
        }
    }
    
    private func mapKitPlaces(
        query: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    ) async -> [NearbyPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest]
        let spanMeters = max(min(radiusMeters, 50_000) * 2, 2_000)
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            latitudinalMeters: spanMeters,
            longitudinalMeters: spanMeters
        )
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.compactMap { item in
                let coordinate = item.location.coordinate
                guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
                let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? query
                return NearbyPlace(
                    id: item.identifier?.rawValue ?? "\(coordinate.latitude)-\(coordinate.longitude)",
                    name: name,
                    formattedAddress: formattedAddress(from: item),
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
        } catch {
            print("[PlacesNew] MapKit \(query) error: \(error.localizedDescription)")
            return []
        }
    }
    
    private func formattedAddress(from item: MKMapItem) -> String? {
        let full = item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
        if let full, !full.isEmpty { return full }
        return item.addressRepresentations?.cityWithContext
    }
    
    private func nearbyPlace(from place: [String: Any]) -> NearbyPlace? {
        let placeId = place["id"] as? String ?? ""
        let name = (place["displayName"] as? [String: Any])?["text"] as? String ?? "Unknown"
        let address = place["formattedAddress"] as? String
        guard let loc = place["location"] as? [String: Any],
              let lat = NearbyPlaceRules.double(from: loc["latitude"]),
              let lng = NearbyPlaceRules.double(from: loc["longitude"]) else {
            return nil
        }
        return NearbyPlace(
            id: placeId.isEmpty ? "\(lat)-\(lng)" : placeId,
            name: name,
            formattedAddress: address,
            latitude: lat,
            longitude: lng
        )
    }
    
    private func placesPOSTRequest(url: URL, apiKey: String, fieldMask: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        request.addValue(Self.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        return request
    }
    
    /// Calls places.searchText (New) and returns the resource name of the first photo, if any.
    /// We request only minimal fields via X-Goog-FieldMask to keep usage low.
    private func findFirstPhotoResourceName(latitude: Double,
                                            longitude: Double,
                                            query: String,
                                            apiKey: String) async -> String? {
        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText") else {
            print("[PlacesNew] Invalid searchText URL")
            return nil
        }
        
        var request = placesPOSTRequest(
            url: url,
            apiKey: apiKey,
            fieldMask: "places.id,places.photos,places.displayName,places.location"
        )
        
        // Tighten search to a ~50m box so we don't get random nearby places
        let delta = 0.00045 // ~50m in degrees
        let body: [String: Any] = [
            "textQuery": query,
            "locationRestriction": [
                "rectangle": [
                    "low": [
                        "latitude": latitude - delta,
                        "longitude": longitude - delta
                    ],
                    "high": [
                        "latitude": latitude + delta,
                        "longitude": longitude + delta
                    ]
                ]
            ],
            "maxResultCount": 10
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("[PlacesNew] Failed to encode searchText body: \(error.localizedDescription)")
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[PlacesNew] searchText HTTP status: \(http.statusCode)")
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let status = json?["status"] as? String {
                print("[PlacesNew] searchText status: \(status)")
            }
            if let error = json?["error"] as? [String: Any] {
                print("[PlacesNew] searchText error: \(error["status"] ?? "") \(error["message"] ?? "")")
            }
            
            guard let places = json?["places"] as? [[String: Any]], !places.isEmpty else {
                print("[PlacesNew] searchText returned no places")
                return nil
            }
            
            let significantWords = significantWords(from: query)
            
            for place in places {
                if let photos = place["photos"] as? [[String: Any]],
                   let firstPhoto = photos.first,
                   let name = firstPhoto["name"] as? String {
                    // Filter by name: at least one significant word from spot must appear in place's display name
                    if !significantWords.isEmpty {
                        let displayText = (place["displayName"] as? [String: Any])?["text"] as? String ?? ""
                        if !nameMatches(displayName: displayText, significantWords: significantWords) {
                            continue
                        }
                    }
                    // Optional distance filter: if place has location, only use if within ~100m
                    if let loc = place["location"] as? [String: Any],
                       let placeLat = NearbyPlaceRules.double(from: loc["latitude"]),
                       let placeLng = NearbyPlaceRules.double(from: loc["longitude"]) {
                        let maxDelta = 0.0009 // ~100m
                        if abs(placeLat - latitude) > maxDelta || abs(placeLng - longitude) > maxDelta {
                            continue
                        }
                    }
                    return name
                }
            }
            
            print("[PlacesNew] searchText returned places but none had photos")
            return nil
        } catch {
            print("[PlacesNew] searchText error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Words of length >= 3 from the spot name (alphanumeric), for matching against place display names.
    private func significantWords(from spotName: String) -> [String] {
        spotName
            .lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }
    
    /// True if at least one of the significant words appears in the place's display name (case-insensitive).
    private func nameMatches(displayName: String, significantWords: [String]) -> Bool {
        let lower = displayName.lowercased()
        return significantWords.contains { lower.contains($0) }
    }
    
    /// Calls Place Photos (New) media endpoint with skipHttpRedirect to obtain a stable photoUri.
    private func fetchPhotoURI(photoName: String, apiKey: String) async -> URL? {
        // photoName looks like \"places/PLACE_ID/photos/PHOTO_ID\"
        // Place Photos (New) media endpoint: https://places.googleapis.com/v1/{name}/media
        let encodedName = photoName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? photoName
        let urlString = "https://places.googleapis.com/v1/\(encodedName)/media?maxWidthPx=800&skipHttpRedirect=true&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            print("[PlacesNew] Invalid photo media URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.addValue(Self.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[PlacesNew] media HTTP status: \(http.statusCode)")
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let uri = json?["photoUri"] as? String {
                return URL(string: uri)
            } else {
                print("[PlacesNew] media response missing photoUri")
                return nil
            }
        } catch {
            print("[PlacesNew] media error: \(error.localizedDescription)")
            return nil
        }
    }
}
