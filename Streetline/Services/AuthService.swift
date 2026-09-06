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
}
