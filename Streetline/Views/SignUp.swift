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
    @State private var birthDate = Date()
    @State private var isSigningUp = false
    @State private var signUpError: String?
    @State private var showContactSupport = false
    @EnvironmentObject var viewModel: LoginViewModel
    @Environment(\.dismiss) var dismiss
    
    private let stickerMagenta = Color(red: 1.0, green: 0.32, blue: 0.72)
    
    private var oldestBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -AgeRules.maximumAge, to: Date()) ?? Date.distantPast
    }
    
    private var passwordsMatch: Bool {
        password == confirmPassword || confirmPassword.isEmpty
    }
    
    private var isOldEnough: Bool {
        AgeRules.isOldEnough(birthDate: birthDate)
    }
    
    private var isFormValid: Bool {
        !email.isEmpty
            && !password.isEmpty
            && !username.isEmpty
            && !confirmPassword.isEmpty
            && passwordsMatch
            && isOldEnough
    }
    
    var body: some View {
        ZStack {
            ArtBackdrop(imageName: "CityImage", dim: 0.2, starBand: .logo)
            
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
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.black)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white))
                    .overlay(
                        Circle().stroke(Color.black, lineWidth: 2.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSigningUp)
            .padding(.top, 20)
            .padding(.leading, 16)
            .accessibilityLabel("Close")
        }
        .toolbar(.hidden, for: .navigationBar)
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
            
            compactField(title: "Birthday") {
                DatePicker(
                    "Birthday",
                    selection: $birthDate,
                    in: oldestBirthDate...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Text(AgeRules.validationMessage(birthDate: birthDate) ?? "Streetline is for ages \(AgeRules.minimumAge) and up.")
                .font(.caption2.weight(.semibold))
                .foregroundColor(isOldEnough ? .secondary : .red)
            
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
        guard isOldEnough else {
            signUpError = AgeRules.validationMessage(birthDate: birthDate)
            return
        }
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
