//
//  UsernameRulesTests.swift
//  StreetlineTests
//

import XCTest
@testable import Streetline

final class UsernameRulesTests: XCTestCase {
    func testValidUsernames() {
        XCTAssertNil(UsernameRules.validate("nate"))
        XCTAssertNil(UsernameRules.validate("Nate_99"))
        XCTAssertNil(UsernameRules.validate("abc"))
        XCTAssertNil(UsernameRules.validate(String(repeating: "a", count: 20)))
        XCTAssertNil(UsernameRules.validate("  skater  "))
    }
    
    func testEmptyAndWhitespace() {
        XCTAssertEqual(UsernameRules.validate(""), "Username cannot be empty")
        XCTAssertEqual(UsernameRules.validate("   "), "Username cannot be empty")
    }
    
    func testLength() {
        XCTAssertEqual(
            UsernameRules.validate("ab"),
            "Username must be at least 3 characters"
        )
        XCTAssertEqual(
            UsernameRules.validate(String(repeating: "a", count: 21)),
            "Username must be at most 20 characters"
        )
    }
    
    func testDisallowedCharacters() {
        XCTAssertEqual(
            UsernameRules.validate("nate smith"),
            "Use only letters, numbers, and underscores"
        )
        XCTAssertEqual(
            UsernameRules.validate("nate!"),
            "Use only letters, numbers, and underscores"
        )
        XCTAssertEqual(
            UsernameRules.validate("nate@app"),
            "Use only letters, numbers, and underscores"
        )
    }
}
