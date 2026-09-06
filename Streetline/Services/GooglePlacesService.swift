//
//  GooglePlacesService.swift
//  SpotFinder
//
//  Fetches place photo URL from Google Places API (New) for a spot's location.
//  Add your API key: Target → Info → Custom iOS Target Properties → GooglePlacesAPIKey
//

import Foundation
import CoreLocation

// MARK: - Nearby place (e.g. skate shop) for list + directions
struct NearbyPlace: Identifiable {
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
    
    /// Read from Target Info: GooglePlacesAPIKey. Restrict key to Places API and iOS app in Google Cloud Console.
    private static var apiKey: String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String
        if let raw, !raw.isEmpty {
            print("[PlacesNew] Loaded API key from Info.plist (length: \(raw.count))")
        } else {
            print("[PlacesNew] GooglePlacesAPIKey missing or empty in target Info")
        }
        return raw
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
    
    /// Search for skate shops near the given coordinate (e.g. map center or city). Uses locationBias so results are in the area.
    /// Radius is in meters (e.g. 10000 for ~10 km / "city area").
    func fetchNearbySkateShops(latitude: Double, longitude: Double, radiusMeters: Double = 10000) async -> [NearbyPlace] {
        guard let key = Self.apiKey, !key.isEmpty else {
            print("[PlacesNew] Aborting fetchNearbySkateShops – no API key")
            return []
        }
        
        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText") else { return [] }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("places.id,places.displayName,places.formattedAddress,places.location", forHTTPHeaderField: "X-Goog-FieldMask")
        
        let body: [String: Any] = [
            "textQuery": "skate shop",
            "locationBias": [
                "circle": [
                    "center": [
                        "latitude": latitude,
                        "longitude": longitude
                    ],
                    "radius": radiusMeters
                ]
            ],
            "maxResultCount": 20
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("[PlacesNew] Failed to encode skate shop search body: \(error.localizedDescription)")
            return []
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[PlacesNew] searchText (skate shops) HTTP status: \(http.statusCode)")
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let errorMessage = json?["error_message"] as? String {
                print("[PlacesNew] searchText error_message: \(errorMessage)")
            }
            
            guard let places = json?["places"] as? [[String: Any]] else {
                return []
            }
            
            var results: [NearbyPlace] = []
            for place in places {
                let placeId = place["id"] as? String ?? ""
                let name = (place["displayName"] as? [String: Any])?["text"] as? String ?? "Unknown"
                let address = place["formattedAddress"] as? String
                guard let loc = place["location"] as? [String: Any],
                      let lat = loc["latitude"] as? Double,
                      let lng = loc["longitude"] as? Double else { continue }
                results.append(NearbyPlace(
                    id: placeId.isEmpty ? "\(lat)-\(lng)" : placeId,
                    name: name,
                    formattedAddress: address,
                    latitude: lat,
                    longitude: lng
                ))
            }
            return results
        } catch {
            print("[PlacesNew] searchText (skate shops) error: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Search for skate parks near the given coordinate.
    func fetchNearbySkateParks(latitude: Double, longitude: Double, radiusMeters: Double = 10000) async -> [NearbyPlace] {
        guard let key = Self.apiKey, !key.isEmpty else {
            print("[PlacesNew] Aborting fetchNearbySkateParks – no API key")
            return []
        }
        
        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText") else { return [] }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("places.id,places.displayName,places.formattedAddress,places.location", forHTTPHeaderField: "X-Goog-FieldMask")
        
        let body: [String: Any] = [
            "textQuery": "skate park",
            "locationBias": [
                "circle": [
                    "center": [
                        "latitude": latitude,
                        "longitude": longitude
                    ],
                    "radius": radiusMeters
                ]
            ],
            "maxResultCount": 20
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("[PlacesNew] Failed to encode skate park search body: \(error.localizedDescription)")
            return []
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[PlacesNew] searchText (skate parks) HTTP status: \(http.statusCode)")
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let errorMessage = json?["error_message"] as? String {
                print("[PlacesNew] skate parks search error_message: \(errorMessage)")
            }
            
            guard let places = json?["places"] as? [[String: Any]] else {
                return []
            }
            
            var results: [NearbyPlace] = []
            for place in places {
                let placeId = place["id"] as? String ?? ""
                let name = (place["displayName"] as? [String: Any])?["text"] as? String ?? "Unknown"
                let address = place["formattedAddress"] as? String
                guard let loc = place["location"] as? [String: Any],
                      let lat = loc["latitude"] as? Double,
                      let lng = loc["longitude"] as? Double else { continue }
                results.append(NearbyPlace(
                    id: placeId.isEmpty ? "\(lat)-\(lng)" : placeId,
                    name: name,
                    formattedAddress: address,
                    latitude: lat,
                    longitude: lng
                ))
            }
            return results
        } catch {
            print("[PlacesNew] searchText (skate parks) error: \(error.localizedDescription)")
            return []
        }
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
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // Request id, photos, displayName (for name filter), location (for distance filter)
        request.addValue("places.id,places.photos,places.displayName,places.location", forHTTPHeaderField: "X-Goog-FieldMask")
        
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
            if let errorMessage = json?["error_message"] as? String {
                print("[PlacesNew] searchText error_message: \(errorMessage)")
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
                       let placeLat = loc["latitude"] as? Double,
                       let placeLng = loc["longitude"] as? Double {
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
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
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
