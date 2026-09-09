//
//  NearbyPlaceRules.swift
//  Streetline
//
//  Filters Google/Apple place results to skate shops and skate parks.
//

import Foundation
import CoreLocation

enum NearbyPlaceRules {
    static func isSkateShop(_ place: NearbyPlace) -> Bool {
        let text = "\(place.name) \(place.formattedAddress ?? "")".lowercased()
        if isSurfOnly(text) { return false }
        if text.contains("snowboard") && !containsSkateTerm(text) { return false }
        return true
    }
    
    static func isSkatePark(_ place: NearbyPlace) -> Bool {
        let name = place.name.lowercased()
        if name.contains("parking") && !containsSkateTerm(name) { return false }
        if isGenericParkName(name) { return false }
        return containsSkateTerm(name)
    }
    
    static func placesWithinRadius(
        _ places: [NearbyPlace],
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    ) -> [NearbyPlace] {
        let origin = CLLocation(latitude: latitude, longitude: longitude)
        let limit = min(max(radiusMeters, 1), 50_000)
        return places
            .filter { place in
                let here = CLLocation(latitude: place.latitude, longitude: place.longitude)
                return origin.distance(from: here) <= limit
            }
            .sorted { lhs, rhs in
                let left = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
                let right = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
                return origin.distance(from: left) < origin.distance(from: right)
            }
    }
    
    static func double(from value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }
    
    private static func isGenericParkName(_ name: String) -> Bool {
        let generic = [
            "national park",
            "state park",
            "regional park",
            "county park",
            "city park",
            "neighborhood park",
            "community park",
            "dog park",
            "amusement park",
            "theme park",
            "water park",
            "industrial park",
            "business park",
            "office park",
            "rv park",
            "mobile home park",
            "playground"
        ]
        return generic.contains { name.contains($0) }
    }
    
    private static func isSurfOnly(_ text: String) -> Bool {
        containsSurfTerm(text) && !containsSkateTerm(text)
    }
    
    private static func containsSkateTerm(_ text: String) -> Bool {
        text.contains("skate") || text.contains("skateboard")
    }
    
    private static func containsSurfTerm(_ text: String) -> Bool {
        text.contains("surfboard") || text.contains("surfing") || text.contains("surf shop")
            || text.range(of: #"\bsurf(s|y)?\b"#, options: .regularExpression) != nil
    }
}
