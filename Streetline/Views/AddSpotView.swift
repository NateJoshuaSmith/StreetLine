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
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var applePlacePreview: UIImage?
    
    private let allTags = ["Street", "Park", "DIY", "Ledge", "Rail", "Hubba", "Bowl", "Red Curb"]
    private let allDifficulties = ["Beginner", "Intermediate", "Advanced"]
    private let allFunLevels = ["Not fun but skateable", "Fun", "Super Fun"]
    private let stickerBlue = Color(red: 0.18, green: 0.78, blue: 1.0)
    
    @State private var selectedTags: Set<String> = []
    @State private var selectedDifficulty: String = "Beginner"
    @State private var selectedStatus: String = "Fun"
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArtBackdrop(imageName: "CityImage", dim: 0.22, starBand: .header)
                
                ScrollView(.vertical, showsIndicators: false) {
                    addSpotCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                        .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 10) {
                    Capsule()
                        .fill(Color.white)
                        .overlay(Capsule().stroke(Color.black, lineWidth: 2))
                        .frame(width: 52, height: 7)
                        .padding(.top, 8)
                        .accessibilityHidden(true)
                    
                    ZStack {
                        Text("New Spot")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(titleCapsule)
                        
                        HStack {
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
                            .disabled(isSaving)
                            .accessibilityLabel("Cancel")
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                }
            }
            .task {
                applePlacePreview = await ApplePlaceImageLoader.image(
                    for: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                )
            }
        }
    }
    
    private var titleCapsule: some View {
        ZStack {
            Capsule().fill(Color.white.opacity(0.95))
            Capsule().strokeBorder(Color.black, lineWidth: 2.5)
        }
    }
    
    private var addSpotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NEW SPOT")
                .font(.title3.weight(.heavy))
                .tracking(1)
                .frame(maxWidth: .infinity)
            
            photoPicker
            
            compactField(title: "Spot Name") {
                TextField("Name this spot", text: $spotName)
                    .textFieldStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.caption.weight(.heavy))
                WrapTagsView(allTags: allTags, selectedTags: $selectedTags)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.caption.weight(.heavy))
                HStack(spacing: 8) {
                    ForEach(allDifficulties, id: \.self) { level in
                        choiceChip(level, isOn: selectedDifficulty == level) {
                            selectedDifficulty = level
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Level of fun")
                    .font(.caption.weight(.heavy))
                HStack(spacing: 8) {
                    ForEach(allFunLevels, id: \.self) { level in
                        choiceChip(level, isOn: selectedStatus == level) {
                            selectedStatus = level
                        }
                    }
                }
            }
            
            if let saveError {
                Text(saveError)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                Task { await saveSpot() }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.heavy))
                    }
                    Text(isSaving ? "SAVING..." : "SAVE SPOT")
                        .font(.subheadline.weight(.heavy))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(canSave ? stickerBlue : Color.gray.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 2.5)
                )
                .shadow(color: canSave ? stickerBlue.opacity(0.7) : .clear, radius: 10, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.7)
            .padding(.top, 4)
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
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }
    
    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spot Photo")
                .font(.caption.weight(.heavy))
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
                                    .font(.caption2.weight(.heavy))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        ZStack {
                                            Capsule().fill(Color.black.opacity(0.62))
                                            Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                                        }
                                    )
                                    .padding(8)
                            }
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(height: 160)
                            .overlay(
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.black)
                                    Text("Loading Apple place photo…")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.black.opacity(0.7))
                                }
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black, lineWidth: 2.5)
                )
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
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 2)
                )
        }
    }
    
    private func choiceChip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.heavy))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isOn ? stickerBlue : Color.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var trimmedName: String {
        spotName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canSave: Bool {
        !trimmedName.isEmpty && !isSaving
    }
    
    private func saveSpot() async {
        guard canSave else { return }
        
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            var imageURL: String?
            if let data = selectedImageData, !data.isEmpty {
                imageURL = try await spotService.uploadSpotImage(data: data)
            } else if let appleData = applePlacePreview?.jpegData(compressionQuality: 0.7) {
                imageURL = try? await spotService.uploadSpotImage(data: appleData)
            }
            try await spotService.addSpot(
                name: trimmedName,
                latitude: latitude,
                longitude: longitude,
                comment: "No comment",
                imageURL: imageURL,
                tags: selectedTags.isEmpty ? nil : Array(selectedTags),
                difficulty: selectedDifficulty,
                status: selectedStatus
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
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

private struct WrapTagsView: View {
    let allTags: [String]
    @Binding var selectedTags: Set<String>
    
    private let stickerBlue = Color(red: 0.18, green: 0.78, blue: 1.0)
    
    private var rows: [[String]] {
        var currentRow: [String] = []
        var result: [[String]] = []
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
                        Button {
                            if isOn {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        } label: {
                            Text(tag)
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity)
                                .background(isOn ? stickerBlue : Color.white.opacity(0.85))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color.black, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
