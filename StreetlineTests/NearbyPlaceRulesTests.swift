//
//  NearbyPlaceRulesTests.swift
//  StreetlineTests
//

import XCTest
@testable import Streetline

final class NearbyPlaceRulesTests: XCTestCase {
    func testKeepsSkateShops() {
        XCTAssertTrue(NearbyPlaceRules.isSkateShop(place("Deluxe Skateshop")))
        XCTAssertTrue(NearbyPlaceRules.isSkateShop(place("FTC SF")))
        XCTAssertTrue(NearbyPlaceRules.isSkateShop(place("Zumiez")))
        XCTAssertTrue(NearbyPlaceRules.isSkateShop(place("Skate and Surf")))
    }
    
    func testDropsSurfOnlyShops() {
        XCTAssertFalse(NearbyPlaceRules.isSkateShop(place("Jack's Surfboards")))
        XCTAssertFalse(NearbyPlaceRules.isSkateShop(place("Ocean Beach Surf Shop")))
        XCTAssertFalse(NearbyPlaceRules.isSkateShop(place("Surf Shop")))
    }
    
    func testKeepsSkateParksByName() {
        XCTAssertTrue(NearbyPlaceRules.isSkatePark(place("Potrero Del Sol Skatepark")))
        XCTAssertTrue(NearbyPlaceRules.isSkatePark(place("SoMa Skate Park")))
        XCTAssertTrue(NearbyPlaceRules.isSkatePark(place("Embarcadero Skate Plaza")))
    }
    
    func testDropsRegularParks() {
        XCTAssertFalse(NearbyPlaceRules.isSkatePark(place("Golden Gate Park")))
        XCTAssertFalse(NearbyPlaceRules.isSkatePark(place("Dolores Park")))
        XCTAssertFalse(NearbyPlaceRules.isSkatePark(place("Yosemite National Park")))
        XCTAssertFalse(NearbyPlaceRules.isSkatePark(place("Alamo Square Dog Park")))
        XCTAssertFalse(NearbyPlaceRules.isSkatePark(place("City Park Playground")))
        XCTAssertFalse(NearbyPlaceRules.isSkatePark(place("Downtown Parking Garage")))
    }
    
    func testRadiusFilterDropsFarPlacesAndSortsNearFirst() {
        let originLat = 37.7749
        let originLng = -122.4194
        let twoMiles: Double = 2 * 1609.34
        
        let close = place("Close Shop", latitude: originLat + 0.01, longitude: originLng)
        let farther = place("Farther Shop", latitude: originLat + 0.02, longitude: originLng)
        let tooFar = place("Too Far Shop", latitude: originLat + 0.08, longitude: originLng)
        
        let result = NearbyPlaceRules.placesWithinRadius(
            [tooFar, farther, close],
            latitude: originLat,
            longitude: originLng,
            radiusMeters: twoMiles
        )
        
        XCTAssertEqual(result.map(\.name), ["Close Shop", "Farther Shop"])
        XCTAssertFalse(result.contains(where: { $0.name == "Too Far Shop" }))
    }
    
    func testJSONNumbersParseFromNSNumberAndString() {
        XCTAssertEqual(NearbyPlaceRules.double(from: NSNumber(value: 37.7749)) ?? .nan, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(NearbyPlaceRules.double(from: 37.7749) ?? .nan, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(NearbyPlaceRules.double(from: "-122.4194") ?? .nan, -122.4194, accuracy: 0.0001)
        XCTAssertNil(NearbyPlaceRules.double(from: "nope"))
        XCTAssertNil(NearbyPlaceRules.double(from: nil))
    }
    
    private func place(
        _ name: String,
        address: String? = nil,
        latitude: Double = 37.7749,
        longitude: Double = -122.4194
    ) -> NearbyPlace {
        NearbyPlace(
            id: name,
            name: name,
            formattedAddress: address,
            latitude: latitude,
            longitude: longitude
        )
    }
}
