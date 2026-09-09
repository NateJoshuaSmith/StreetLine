//
//  ModelLogicTests.swift
//  StreetlineTests
//

import XCTest
@testable import Streetline

final class ModelLogicTests: XCTestCase {
    func testUserProfileHasSkateDetails() {
        let empty = UserProfile(uid: "1", username: "nate")
        XCTAssertFalse(empty.hasSkateDetails)
        
        let withAge = UserProfile(uid: "1", username: "nate", age: 21)
        XCTAssertTrue(withAge.hasSkateDetails)
        
        let withTrick = UserProfile(uid: "1", username: "nate", favoriteTrick: "kickflip")
        XCTAssertTrue(withTrick.hasSkateDetails)
    }
    
    func testUserProfileEqualityIsByUid() {
        let a = UserProfile(uid: "same", username: "one")
        let b = UserProfile(uid: "same", username: "two")
        let c = UserProfile(uid: "other", username: "one")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
    
    func testCommunityPostDisplayWherePrefersSpotName() {
        let post = CommunityPost(
            createdBy: "u1",
            createdByUsername: "nate",
            text: "session",
            spotName: "Hubba",
            locationText: "typed place"
        )
        XCTAssertEqual(post.displayWhere, "Hubba")
        
        let typed = CommunityPost(
            createdBy: "u1",
            createdByUsername: "nate",
            text: "session",
            locationText: "schoolyard"
        )
        XCTAssertEqual(typed.displayWhere, "schoolyard")
        
        let nowhere = CommunityPost(createdBy: "u1", createdByUsername: "nate", text: "session")
        XCTAssertNil(nowhere.displayWhere)
    }
    
    func testCommunityPostExpiryUsesSessionPlus24Hours() {
        let live = CommunityPost(
            createdBy: "u1",
            createdByUsername: "nate",
            text: "later",
            sessionAt: Date().addingTimeInterval(60 * 60),
            expiresAt: Date().addingTimeInterval(25 * 60 * 60)
        )
        XCTAssertFalse(live.isExpired)
        
        let expired = CommunityPost(
            createdBy: "u1",
            createdByUsername: "nate",
            text: "past",
            sessionAt: Date().addingTimeInterval(-48 * 60 * 60),
            expiresAt: Date().addingTimeInterval(-1)
        )
        XCTAssertTrue(expired.isExpired)
    }
    
    func testLobbyMessageExpiry() {
        let fresh = LobbyMessage(senderId: "u1", senderUsername: "nate", text: "hey", createdAt: Date())
        XCTAssertFalse(fresh.isExpired)
        
        let old = LobbyMessage(
            senderId: "u1",
            senderUsername: "nate",
            text: "hey",
            createdAt: Date().addingTimeInterval(-LobbyMessage.lifetime - 1)
        )
        XCTAssertTrue(old.isExpired)
    }
    
    func testSkateSpotPrimaryImagePrefersGalleryThenLegacy() {
        var spot = SkateSpot(
            name: "Ledge",
            latitude: 1,
            longitude: 2,
            comment: "No comment",
            createdBy: "u1",
            imageURL: "https://legacy.jpg",
            imageURLs: ["  ", "https://one.jpg", "https://two.jpg"]
        )
        XCTAssertEqual(spot.primaryImageURLString, "https://one.jpg")
        
        spot.imageURLs = nil
        XCTAssertEqual(spot.primaryImageURLString, "https://legacy.jpg")
        
        spot.imageURL = "  "
        XCTAssertNil(spot.primaryImageURLString)
    }
    
    func testSessionTypesStayStable() {
        XCTAssertEqual(CommunityPost.sessionTypes, ["Street", "Park", "DIY", "Bowl", "Mini", "Mixed"])
        XCTAssertEqual(UserProfile.skillLevels, ["Beginner", "Intermediate", "Advanced"])
    }
    
    func testBlockedUserCache() {
        UserService.clearBlockedCache()
        XCTAssertFalse(UserService.isUserBlocked("bad-actor"))
        UserService.storeBlockedIds(["bad-actor", "other"])
        XCTAssertTrue(UserService.isUserBlocked("bad-actor"))
        XCTAssertFalse(UserService.isUserBlocked("friend"))
        UserService.clearBlockedCache()
        XCTAssertFalse(UserService.isUserBlocked("bad-actor"))
    }
}
