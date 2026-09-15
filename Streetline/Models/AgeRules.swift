//
//  AgeRules.swift
//  Streetline
//
//  Minimum age to create an account. Required for COPPA and App Store review.
//

import Foundation

enum AgeRules {
    static let minimumAge = 13
    static let maximumAge = 99
    
    static func age(from birthDate: Date, asOf now: Date = Date()) -> Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: now).year ?? 0
    }
    
    static func isOldEnough(birthDate: Date, asOf now: Date = Date()) -> Bool {
        let years = age(from: birthDate, asOf: now)
        return years >= minimumAge && years <= maximumAge
    }
    
    /// Returns nil if eligible, or an error message.
    static func validationMessage(birthDate: Date, asOf now: Date = Date()) -> String? {
        let years = age(from: birthDate, asOf: now)
        if years < minimumAge {
            return "You must be \(minimumAge) or older to use Streetline"
        }
        if years > maximumAge {
            return "Please enter a valid birth date"
        }
        return nil
    }
}
