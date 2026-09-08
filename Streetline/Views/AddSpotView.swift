//
//  AddSpotView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI
import PhotosUI
import MapKit

struct AddSpotView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var spotService: SpotService
    
    let latitude: Double
    let longitude: Double
    
    @State private var spotName: String = ""
    @State private var spotComment: String = ""
    @State private var isSaving: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var applePlacePreview: UIImage?
    
    // Tag / difficulty / fun level options
    private let allTags = ["Street", "Park", "DIY", "Ledge", "Rail", "Hubba", "Bowl", "Red Curb"]
    private let allDifficulties = ["Beginner", "Intermediate", "Advanced"]
    private let allFunLevels = ["Not fun but skateable", "Fun", "Super Fun"]
    
    @State private var selectedTags: Set<String> = []
    @State private var selectedDifficulty: String = "Beginner"
    @State private var selectedStatus: String = "Fun"
    
    var body: some View {
        NavigationView {
            ZStack {
                // Light blue gradient (same as skate shops / skate parks sheets)
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Spot photo (optional)
                        bubbleCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Spot Photo")
                                    .font(.headline)
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Group {
                                        if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 160)
                                                .frame(maxWidth: .infinity)
                                                .clipped()
                                        } else if let applePlacePreview {
                                            Image(uiImage: applePlacePreview)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 160)
                                                .frame(maxWidth: .infinity)
                                                .clipped()
                                                .overlay(alignment: .bottom) {
                                                    Text("Apple Look Around · tap to replace")
                                                        .font(.caption2.weight(.semibold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.black.opacity(0.55))
                                                        .clipShape(Capsule())
                                                        .padding(8)
                                                }
                                        } else {
                                            Rectangle()
                                                .fill(Color(.systemGray5))
                                                .frame(height: 160)
                                                .overlay(
                                                    VStack(spacing: 8) {
                                                        ProgressView()
                                                        Text("Loading Apple place photo…")
                                                            .font(.subheadline)
                                                            .foregroundColor(.secondary)
                                                    }
                                                )
                                        }
                                    }
                                    .cornerRadius(12)
                                }
                                .onChange(of: selectedPhotoItem) { _, newItem in
                                    Task {
                                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                            selectedImageData = data
                                        } else {
                                            selectedImageData = nil
                                        }
                                    }
                                }
                            }
                        }
                        
                        bubbleCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Spot Information")
                                    .font(.headline)
                                TextField("Spot Name", text: $spotName)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                        
                        bubbleCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                TextField("Add a comment about this spot...", text: $spotComment, axis: .vertical)
                                    .lineLimit(5...30)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                        
                        bubbleCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.headline)
                                WrapTagsView(
                                    allTags: allTags,
                                    selectedTags: $selectedTags
                                )
                            }
                        }
                        
                        bubbleCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Difficulty")
                                    .font(.headline)
                                Picker("Difficulty", selection: $selectedDifficulty) {
                                    ForEach(allDifficulties, id: \.self) { level in
                                        Text(level).tag(level)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        bubbleCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Level of fun")
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    ForEach(allFunLevels, id: \.self) { level in
                                        let isOn = selectedStatus == level
                                        Text(level)
                                            .font(.subheadline)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(isOn ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                            .foregroundColor(isOn ? .blue : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .onTapGesture {
                                                selectedStatus = level
                                            }
                                    }
                                }
                            }
                        }
                        
                        bubbleCard {
                            Button(action: {
                                Task {
                                    await saveSpot()
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    if isSaving {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.headline)
                                    }
                                    Text(isSaving ? "Saving..." : "Save Spot")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            spotName.isEmpty || isSaving
                                                ? LinearGradient(
                                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                                : LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(spotName.isEmpty || isSaving)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Spot")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.95))
                        )
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .task {
                applePlacePreview = await ApplePlaceImageLoader.image(
                    for: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                )
            }
        }
    }
    
    /// Centered bubble card matching skate shops / friends list style
    @ViewBuilder
    private func bubbleCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            Spacer(minLength: 0)
            content()
                .frame(maxWidth: 360, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                )
            Spacer(minLength: 0)
        }
    }
    
    private func saveSpot() async {
        guard !spotName.isEmpty else { return }
        
        isSaving = true
        defer { isSaving = false }
        do {
            var imageURL: String?
            if let data = selectedImageData, !data.isEmpty {
                imageURL = try await spotService.uploadSpotImage(data: data)
            } else if let appleData = applePlacePreview?.jpegData(compressionQuality: 0.78) {
                imageURL = try await spotService.uploadSpotImage(data: appleData)
            }
            try await spotService.addSpot(
                name: spotName,
                latitude: latitude,
                longitude: longitude,
                comment: spotComment.isEmpty ? "No comment" : spotComment,
                imageURL: imageURL,
                tags: selectedTags.isEmpty ? nil : Array(selectedTags),
                difficulty: selectedDifficulty,
                status: selectedStatus
            )
            dismiss()
        } catch {
            print("Error saving spot: \(error)")
        }
    }
}

#Preview {
    AddSpotView(
        spotService: SpotService(),
        latitude: 37.7749,
        longitude: -122.4194
    )
}

// Simple wrapping layout for tag chips
private struct WrapTagsView: View {
    let allTags: [String]
    @Binding var selectedTags: Set<String>
    
    // Precompute rows of tags (plain Swift, no ViewBuilder)
    private var rows: [[String]] {
        var currentRow: [String] = []
        var result: [[String]] = []
        
        // Very simple wrapping: break rows every 3 items
        for tag in allTags {
            currentRow.append(tag)
            if currentRow.count == 3 {
                result.append(currentRow)
                currentRow = []
            }
        }
        if !currentRow.isEmpty {
            result.append(currentRow)
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { tag in
                        let isOn = selectedTags.contains(tag)
                        Text(tag)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isOn ? Color.blue.opacity(0.2) : Color(.systemGray6))
                            .foregroundColor(isOn ? .blue : .primary)
                            .clipShape(Capsule())
                            .onTapGesture {
                                if isOn {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                    }
                }
            }
        }
    }
}
