//
//  SettingsView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI
import FirebaseAuth
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @StateObject private var userService = UserService()
    @State private var userEmail: String = ""
    @State private var currentUsername: String?
    @State private var avatarURL: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var showContactSupport = false
    @State private var showChangeUsername = false
    @State private var showChangeEmail = false
    @State private var showDeleteAccount = false
    @State private var showBlockedUsers = false
    
    var body: some View {
        ZStack {
            Image("SettingPage")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                settingsCard
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("") // custom styled title bubble like other screens
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.systemGray5)))
            }
        }
        .sheet(isPresented: $showContactSupport) {
            ContactSupportView.sheet
        }
        .onAppear {
            if let user = Auth.auth().currentUser {
                userEmail = user.email ?? "No email"
            }
            // Use cached avatar URL immediately so we don't wait on Firestore
            avatarURL = viewModel.avatarURL
            Task {
                currentUsername = await userService.getCurrentUsername()
                // Refresh avatar URL in the background and keep cache in sync
                let freshURL = await userService.getCurrentAvatarURL()
                await MainActor.run {
                    avatarURL = freshURL
                    viewModel.avatarURL = freshURL
                }
            }
        }
        .onChange(of: showChangeUsername) { _, isShowing in
            if !isShowing {
                Task { currentUsername = await userService.getCurrentUsername() }
            }
        }
        .sheet(isPresented: $showChangeUsername) {
            ChangeUsernameView(
                currentUsername: currentUsername,
                userService: userService,
                onDismiss: {
                    showChangeUsername = false
                    Task { currentUsername = await userService.getCurrentUsername() }
                }
            )
        }
        .sheet(isPresented: $showChangeEmail) {
            ChangeEmailView(
                currentEmail: userEmail,
                userService: userService,
                onDismiss: {
                    showChangeEmail = false
                    if let email = Auth.auth().currentUser?.email {
                        userEmail = email
                    }
                }
            )
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView(
                onDismiss: { showDeleteAccount = false }
            )
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showBlockedUsers) {
            BlockedUsersView(userService: userService)
        }
    }
    
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                avatarPicker
                
                VStack(alignment: .leading, spacing: 4) {
                    if let name = currentUsername, !name.isEmpty {
                        Text("@\(name)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    } else {
                        Text("Your profile")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    Text(userEmail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Tap photo to change")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 0)
            }
            .padding(.bottom, 16)
            
            Divider()
            
            Button(action: { showChangeUsername = true }) {
                settingsRow(
                    title: "Change username",
                    systemImage: "at.circle.fill",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            
            Button(action: { showChangeEmail = true }) {
                settingsRow(
                    title: "Change email",
                    systemImage: "envelope.badge.fill",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            
            sectionLabel("About")
            
            settingsRow(
                title: "Version",
                systemImage: "info.circle.fill",
                value: appVersion
            )
            
            settingsRow(
                title: "App Name",
                systemImage: "app.fill",
                value: "Streetline"
            )
            
            sectionLabel("Help")
            
            Button(action: { showContactSupport = true }) {
                settingsRow(
                    title: "Contact Support",
                    systemImage: "envelope.fill",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            
            Button(action: { showBlockedUsers = true }) {
                settingsRow(
                    title: "Blocked users",
                    systemImage: "hand.raised.fill",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            
            sectionLabel("Account")
            
            Button(role: .destructive, action: { showDeleteAccount = true }) {
                settingsRow(
                    title: "Delete account",
                    systemImage: "trash.fill",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: 355)
        .background(settingsCardBackground)
        .frame(maxWidth: .infinity)
    }
    
    private var settingsCardBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color.white.opacity(0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.purple.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.black, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
    }
    
    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Group {
                if let urlString = avatarURL, let url = URL(string: urlString) {
                    ZStack {
                        avatarPlaceholder
                        AsyncImage(
                            url: url,
                            transaction: Transaction(animation: .easeInOut)
                        ) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .transition(.opacity)
                            case .empty:
                                Color.clear
                            case .failure:
                                avatarPlaceholder
                            @unknown default:
                                avatarPlaceholder
                            }
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .overlay(isUploadingAvatar ? ProgressView().tint(.white) : nil)
                } else {
                    avatarPlaceholder
                        .overlay(isUploadingAvatar ? ProgressView().tint(.white) : nil)
                }
            }
            .frame(width: 72, height: 72)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 2)
            )
        }
        .disabled(isUploadingAvatar)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let item = newItem else { return }
            Task { await uploadAvatar(from: item) }
        }
    }
    
    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
            .padding(.bottom, 4)
    }
    
    private func settingsRow(
        title: String,
        systemImage: String,
        value: String? = nil,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundColor(.blue)
                .frame(width: 22)
            Text(title)
                .font(.body.weight(.medium))
                .foregroundColor(.primary)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 72, height: 72)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.title3)
            )
    }
    
    private func uploadAvatar(from item: PhotosPickerItem) async {
        isUploadingAvatar = true
        selectedPhotoItem = nil
        defer { isUploadingAvatar = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else { return }
            let urlString = try await userService.uploadAvatar(data: data)
            await MainActor.run {
                avatarURL = urlString
                viewModel.avatarURL = urlString
            }
        } catch {
            print("Avatar upload failed: \(error)")
        }
    }
}


// MARK: - Change Username
struct ChangeUsernameView: View {
    let currentUsername: String?
    @ObservedObject var userService: UserService
    var onDismiss: () -> Void
    
    @State private var username: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isSaving)
                } header: {
                    Text("New username")
                } footer: {
                    Text("\(UserService.usernameMinLength)–\(UserService.usernameMaxLength) characters, letters, numbers, and underscores only.")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Change username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveUsername() }
                    }
                    .disabled(isSaving || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                username = currentUsername ?? ""
            }
            .alert("Username updated", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                    onDismiss()
                }
            } message: {
                Text("Your username is now @\(username.trimmingCharacters(in: .whitespacesAndNewlines)).")
            }
        }
    }
    
    private func saveUsername() async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validationError = userService.validateUsername(trimmed) {
            errorMessage = validationError
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await userService.updateUsername(trimmed)
            showSuccess = true
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Change Email
struct ChangeEmailView: View {
    let currentEmail: String
    @ObservedObject var userService: UserService
    var onDismiss: () -> Void
    
    @State private var newEmail: String = ""
    @State private var confirmEmail: String = ""
    @State private var currentPassword: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    private let authService = AuthService()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(currentEmail)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Current email")
                }
                
                Section {
                    TextField("New email", text: $newEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .disabled(isSaving)
                    TextField("Confirm new email", text: $confirmEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .disabled(isSaving)
                    SecureField("Current password", text: $currentPassword)
                        .textContentType(.password)
                        .disabled(isSaving)
                } header: {
                    Text("New email")
                } footer: {
                    Text("Enter your current password to confirm this change.")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Change email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveEmail() }
                    }
                    .disabled(isSaving || !isFormValid)
                }
            }
            .alert("Email updated", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                    onDismiss()
                }
            } message: {
                Text(successMessage ?? "Your email has been updated.")
            }
        }
    }
    
    private var isFormValid: Bool {
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirm = confirmEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !email.isEmpty && !confirm.isEmpty && !currentPassword.isEmpty
    }
    
    private func saveEmail() async {
        let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirm = confirmEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased() == confirm.lowercased() else {
            errorMessage = "New email addresses do not match"
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let changedImmediately = try await authService.updateEmail(
                to: trimmed,
                currentPassword: currentPassword
            )
            if changedImmediately {
                try await userService.updateEmail(trimmed)
                successMessage = "Your email is now \(trimmed)."
            } else {
                successMessage = "Check \(trimmed) and tap the verification link. Your login email updates after you verify."
            }
            showSuccess = true
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Delete Account
struct DeleteAccountView: View {
    var onDismiss: () -> Void
    
    @EnvironmentObject var viewModel: LoginViewModel
    @EnvironmentObject var activityService: ActivityService
    @Environment(\.dismiss) private var dismiss
    
    @State private var password = ""
    @State private var typedConfirm = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This permanently deletes your Streetline account, spots you added, photos, posts, and messages. This cannot be undone.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    SecureField("Current password", text: $password)
                        .textContentType(.password)
                        .disabled(isDeleting)
                    TextField("Type DELETE to confirm", text: $typedConfirm)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .disabled(isDeleting)
                } footer: {
                    Text("Enter your password, then type DELETE.")
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                    .disabled(isDeleting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete", role: .destructive) {
                        Task { await deleteAccount() }
                    }
                    .disabled(isDeleting || !canDelete)
                }
            }
        }
    }
    
    private var canDelete: Bool {
        !password.isEmpty && typedConfirm.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE"
    }
    
    private func deleteAccount() async {
        errorMessage = nil
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await viewModel.deleteAccount(currentPassword: password)
            activityService.stopListening()
            dismiss()
            onDismiss()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Blocked users

struct BlockedUsersView: View {
    @ObservedObject var userService: UserService
    @Environment(\.dismiss) private var dismiss
    @State private var profiles: [UserProfile] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if profiles.isEmpty {
                    EmptyStateCard(
                        title: "No blocked users",
                        systemImage: "hand.raised.slash",
                        message: "People you block are hidden from posts, comments, and messages."
                    )
                } else {
                    List(profiles, id: \.uid) { profile in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(profile.username)")
                                    .font(.headline)
                            }
                            Spacer()
                            Button("Unblock") {
                                Task {
                                    try? await userService.unblockUser(profile.uid)
                                    profiles.removeAll { $0.uid == profile.uid }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Blocked users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                profiles = await userService.fetchBlockedProfiles()
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(LoginViewModel())
            .environmentObject(ActivityService())
    }
}

