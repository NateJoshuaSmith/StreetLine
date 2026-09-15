//
//  AgeRulesTests.swift
//  StreetlineTests
//

import XCTest
@testable import Streetline

final class AgeRulesTests: XCTestCase {
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 15))!
    
    func testExactlyThirteenIsOldEnough() {
        let birthDate = Calendar.current.date(byAdding: .year, value: -13, to: now)!
        XCTAssertEqual(AgeRules.age(from: birthDate, asOf: now), 13)
        XCTAssertTrue(AgeRules.isOldEnough(birthDate: birthDate, asOf: now))
        XCTAssertNil(AgeRules.validationMessage(birthDate: birthDate, asOf: now))
    }
    
    func testTwelveIsTooYoung() {
        let birthDate = Calendar.current.date(byAdding: .year, value: -12, to: now)!
        XCTAssertEqual(AgeRules.age(from: birthDate, asOf: now), 12)
        XCTAssertFalse(AgeRules.isOldEnough(birthDate: birthDate, asOf: now))
        XCTAssertEqual(
            AgeRules.validationMessage(birthDate: birthDate, asOf: now),
            "You must be 13 or older to use Streetline"
        )
    }
    
    func testBirthdayTomorrowIsStillTwelve() {
        let almostThirteen = Calendar.current.date(byAdding: .day, value: 1, to:
            Calendar.current.date(byAdding: .year, value: -13, to: now)!
        )!
        XCTAssertEqual(AgeRules.age(from: almostThirteen, asOf: now), 12)
        XCTAssertFalse(AgeRules.isOldEnough(birthDate: almostThirteen, asOf: now))
    }
    
    func testAdultIsOldEnough() {
        let birthDate = Calendar.current.date(byAdding: .year, value: -21, to: now)!
        XCTAssertTrue(AgeRules.isOldEnough(birthDate: birthDate, asOf: now))
        XCTAssertNil(AgeRules.validationMessage(birthDate: birthDate, asOf: now))
    }
}
