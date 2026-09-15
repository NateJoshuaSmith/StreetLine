//
//  SetUsernameView.swift
//  SpotFinder
//
//  Shown to existing users who don't have a username profile yet.
//

import SwiftUI

struct SetUsernameView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @State private var username = ""
    @State private var birthDate = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private var oldestBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -AgeRules.maximumAge, to: Date()) ?? Date.distantPast
    }
    
    private var isOldEnough: Bool {
        AgeRules.isOldEnough(birthDate: birthDate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Choose a username to display on your spots")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 32)
                    .autocapitalization(.none)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Birthday")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    DatePicker(
                        "Birthday",
                        selection: $birthDate,
                        in: oldestBirthDate...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    Text(AgeRules.validationMessage(birthDate: birthDate) ?? "Streetline is for ages \(AgeRules.minimumAge) and up.")
                        .font(.caption)
                        .foregroundColor(isOldEnough ? .secondary : .red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button(action: saveUsername) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isSaving ? "Saving..." : "Continue")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(username.isEmpty || !isOldEnough ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(username.isEmpty || !isOldEnough || isSaving)
                .padding(.horizontal, 32)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Set Username")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func saveUsername() {
        guard !username.isEmpty else { return }
        guard isOldEnough else {
            errorMessage = AgeRules.validationMessage(birthDate: birthDate)
            return
        }
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.completeUsernameSetup(username: username)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
