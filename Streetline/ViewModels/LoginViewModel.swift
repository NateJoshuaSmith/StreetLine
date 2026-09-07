import SwiftUI
import Combine

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoggedIn = false
    @Published var needsUsernameSetup = false  // For existing users without a profile
    @Published var avatarURL: String?          // Cached avatar URL for current user
    /// False until Firebase has restored (or ruled out) a saved session. Avoids flashing Login.
    @Published var hasResolvedAuth = false
    
    private let authService = AuthService()
    private let userService = UserService()
    private var didRestoreSession = false
    
    /// Rehydrate from Firebase's saved session after a cold launch. Logout still requires Sign Out.
    func restoreSession() async {
        guard !didRestoreSession else { return }
        didRestoreSession = true
        
        guard let uid = await authService.waitForInitialUserId() else {
            await MainActor.run { hasResolvedAuth = true }
            return
        }
        
        let hasProfile = await userService.hasProfile(uid: uid)
        let avatar = await userService.getCurrentAvatarURL()
        await MainActor.run {
            needsUsernameSetup = !hasProfile
            avatarURL = avatar
            isLoggedIn = true
            hasResolvedAuth = true
            if let email = authService.currentUserEmail {
                print("Restored session as: \(email)")
            }
        }
    }

    func login(email: String, password: String) async {
        do {
            try await authService.signIn(email: email, password: password)
            if let uid = authService.currentUserId {
                let hasProfile = await userService.hasProfile(uid: uid)
                if !hasProfile {
                    needsUsernameSetup = true
                }
            }
            isLoggedIn = true
            if let email = authService.currentUserEmail {
                print("Logged in as: \(email)")
            }
            // Prefetch avatar URL after login
            Task {
                let url = await userService.getCurrentAvatarURL()
                await MainActor.run { self.avatarURL = url }
            }
        } catch {
            print("Error signing in: \(error)")
        }
    }

    func signUp(email: String, password: String, username: String) async throws {
        do {
            try await authService.signUp(email: email, password: password)
            if let uid = authService.currentUserId {
                try await userService.createProfile(uid: uid, username: username, email: email)
            }
            isLoggedIn = true
            print("Sign up successful!")
            // Prefetch avatar URL after sign up (will likely be nil initially)
            Task {
                let url = await userService.getCurrentAvatarURL()
                await MainActor.run { self.avatarURL = url }
            }
        } catch {
            print("Error signing up: \(error)")
            throw error
        }
    }
    
    func completeUsernameSetup(username: String) async throws {
        guard let uid = authService.currentUserId else { return }
        try await userService.createProfile(uid: uid, username: username, email: authService.currentUserEmail)
        needsUsernameSetup = false
    }
    
    func logout() async {
        do {
            try authService.signOut()
            UserService.clearFriendsListDisplayCache()
            print("Logout successful!")
            isLoggedIn = false
            avatarURL = nil
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    /// Reauthenticate, delete Firestore/Storage data, then delete the Firebase Auth user.
    func deleteAccount(currentPassword: String) async throws {
        try await authService.reauthenticate(currentPassword: currentPassword)
        try await userService.deleteAllAccountData()
        try await authService.deleteCurrentUser()
        UserService.clearFriendsListDisplayCache()
        await MainActor.run {
            isLoggedIn = false
            needsUsernameSetup = false
            avatarURL = nil
            email = ""
            password = ""
        }
    }
}
