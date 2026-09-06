//
//  AuthService.swift
//  SpotFinder
//
//  Wraps Firebase Auth - single place for all authentication logic.
//

import Foundation
import FirebaseAuth

class AuthService {
    private let auth = Auth.auth()
    
    /// Current user's UID, or nil if not signed in
    var currentUserId: String? {
        auth.currentUser?.uid
    }
    
    /// Current user's email, or nil if not signed in
    var currentUserEmail: String? {
        auth.currentUser?.email
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }
    
    /// Create new account with email and password
    func signUp(email: String, password: String) async throws {
        try await auth.createUser(withEmail: email, password: password)
    }
    
    /// Sign out the current user
    func signOut() throws {
        try auth.signOut()
    }
    
    /// Change the signed-in user's email. Requires their current password.
    /// Prefers Firebase's verify-then-update flow; falls back to an immediate update.
    /// Returns `true` if the Auth email changed right away, `false` if the user must verify the new address.
    @discardableResult
    func updateEmail(to newEmail: String, currentPassword: String) async throws -> Bool {
        guard let user = auth.currentUser, let currentEmail = user.email else {
            throw NSError(domain: "AuthService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            throw NSError(domain: "AuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address"])
        }
        guard trimmed != currentEmail.lowercased() else {
            throw NSError(domain: "AuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "That's already your email"])
        }
        
        let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: currentPassword)
        do {
            try await user.reauthenticate(with: credential)
        } catch {
            throw NSError(domain: "AuthService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Current password is incorrect"])
        }
        
        do {
            try await user.sendEmailVerification(beforeUpdatingEmail: trimmed)
            return false
        } catch {
            try await user.updateEmail(to: trimmed)
            return true
        }
    }
}
