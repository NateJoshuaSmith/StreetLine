//
//  UsernameRules.swift
//  Streetline
//

import Foundation

enum UsernameRules {
    static let minLength = 3
    static let maxLength = 20
    static let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    
    /// Returns nil if valid, or an error message.
    static func validate(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Username cannot be empty"
        }
        if trimmed.count < minLength {
            return "Username must be at least \(minLength) characters"
        }
        if trimmed.count > maxLength {
            return "Username must be at most \(maxLength) characters"
        }
        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            return "Use only letters, numbers, and underscores"
        }
        return nil
    }
}
