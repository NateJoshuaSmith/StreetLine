//
//  Login.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI

struct Login: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @EnvironmentObject var viewModel: LoginViewModel
    @State private var showContactSupport = false
    @State private var showSignUp = false

    private let stickerBlue = Color(red: 0.18, green: 0.78, blue: 1.0)
    
    var body: some View {
        ZStack {
            cityBackdrop
            
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                
                StreetlineLogoBadge(showsOutline: true)
                    .frame(maxWidth: .infinity)
                
                Spacer(minLength: 12)
                
                loginForm
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showContactSupport) {
            ContactSupportView.sheet
        }
        .sheet(isPresented: $showSignUp) {
            NavigationStack {
                SignUp()
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .overlay(
                        Capsule()
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .frame(width: 52, height: 7)
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
    
    private var cityBackdrop: some View {
        ArtBackdrop(imageName: "CityImage", starBand: .logo)
    }
    
    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SIGN IN")
                .font(.title3.weight(.heavy))
                .tracking(1)
                .frame(maxWidth: .infinity)
            
            compactField(title: "Email") {
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            
            compactField(title: "Password") {
                SecureField("Enter your password", text: $password)
            }
            
            Button(action: {
                Task {
                    isLoggingIn = true
                    await viewModel.login(email: email, password: password)
                    isLoggingIn = false
                }
            }) {
                HStack(spacing: 8) {
                    if isLoggingIn {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.heavy))
                    }
                    Text(isLoggingIn ? "SIGNING IN..." : "SIGN IN")
                        .font(.subheadline.weight(.heavy))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(stickerBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 2.5)
                )
                .shadow(color: stickerBlue.opacity(0.7), radius: 10, y: 3)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)
            .padding(.top, 4)
            
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                Text("Don't have an account?")
                    .foregroundColor(.secondary)
                Button("SIGN UP") {
                    showSignUp = true
                }
                .fontWeight(.heavy)
                .foregroundColor(.black)
                Spacer(minLength: 0)
            }
            .font(.caption)
            
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
}

#Preview {
    NavigationView {
        Login()
            .environmentObject(LoginViewModel())
    }
}
