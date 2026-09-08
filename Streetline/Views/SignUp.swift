//
//  SignUp.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI

struct SignUp: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var confirmPassword = ""
    @State private var isSigningUp = false
    @State private var signUpError: String?
    @State private var showContactSupport = false
    @EnvironmentObject var viewModel: LoginViewModel
    @Environment(\.dismiss) var dismiss
    
    private let stickerMagenta = Color(red: 1.0, green: 0.32, blue: 0.72)
    
    private var passwordsMatch: Bool {
        password == confirmPassword || confirmPassword.isEmpty
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && !username.isEmpty && !confirmPassword.isEmpty && passwordsMatch
    }
    
    var body: some View {
        ZStack {
            ArtBackdrop(imageName: "CityImage", dim: 0.2)
            
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack {
                        StreetlineLogoBadge(showsOutline: true)
                            .padding(.top, 36)
                        
                        Spacer(minLength: 16)
                        signUpCard
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(
                            ZStack {
                                Circle().fill(Color.white.opacity(0.95))
                                Circle().strokeBorder(Color.black, lineWidth: 2.5)
                            }
                        )
                }
                .disabled(isSigningUp)
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showContactSupport) {
            ContactSupportView.sheet
        }
    }
    
    private var signUpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SIGN UP")
                .font(.title3.weight(.heavy))
                .tracking(1)
                .frame(maxWidth: .infinity)
            
            compactField(title: "Username") {
                TextField("Choose a username", text: $username)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            compactField(title: "Email") {
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
            
            compactField(title: "Password") {
                SecureField("Create a password", text: $password)
            }
            
            compactField(title: "Confirm password") {
                SecureField("Confirm your password", text: $confirmPassword)
            }
            
            if !confirmPassword.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(passwordsMatch ? "Passwords match" : "Passwords do not match")
                }
                .font(.caption2.weight(.semibold))
                .foregroundColor(passwordsMatch ? .green : .red)
            }
            
            if let error = signUpError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Button(action: submitSignUp) {
                HStack(spacing: 8) {
                    if isSigningUp {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.subheadline.weight(.heavy))
                    }
                    Text(isSigningUp ? "CREATING..." : "SIGN UP")
                        .font(.subheadline.weight(.heavy))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(stickerMagenta)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 2.5)
                )
                .shadow(color: stickerMagenta.opacity(0.7), radius: 10, y: 3)
            }
            .disabled(!isFormValid || isSigningUp)
            .opacity(isFormValid ? 1.0 : 0.6)
            .padding(.top, 2)
            
            Button {
                showContactSupport = true
            } label: {
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Image(systemName: "envelope.fill")
                    Text("Contact Support")
                    Spacer(minLength: 0)
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black, lineWidth: 2.5)
        )
    }
    
    private func compactField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.heavy))
            content()
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    private func submitSignUp() {
        Task {
            isSigningUp = true
            signUpError = nil
            do {
                try await viewModel.signUp(email: email, password: password, username: username)
                dismiss()
            } catch {
                signUpError = error.localizedDescription
            }
            isSigningUp = false
        }
    }
}

#Preview {
    NavigationStack {
        SignUp()
            .environmentObject(LoginViewModel())
    }
}
