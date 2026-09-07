//
//  StreetViewCard.swift
//  Streetline
//
//  Apple Look Around street-level panorama, with Google Street View as fallback.
//

import SwiftUI
import MapKit
import UIKit

struct StreetViewTarget: Identifiable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct StreetViewCard: View {
    let coordinate: CLLocationCoordinate2D
    let title: String
    
    @State private var scene: MKLookAroundScene?
    @State private var isLoading = true
    @State private var showFullScreen = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Street view", systemImage: "binoculars.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                        .frame(height: 180)
                    ProgressView("Loading street view…")
                }
            } else if scene != nil {
                LookAroundPreview(scene: $scene)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                
                Button {
                    showFullScreen = true
                } label: {
                    Label("Open full street view", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Look Around isn’t available at this spot. You can still open Google Street View.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button {
                        StreetViewLinks.openGoogleStreetView(coordinate: coordinate)
                    } label: {
                        Label("Open Google Street View", systemImage: "globe")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task(id: "\(coordinate.latitude),\(coordinate.longitude)") {
            await loadScene()
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let scene {
                StreetViewFullScreen(scene: scene, title: title)
            }
        }
    }
    
    private func loadScene() async {
        isLoading = true
        scene = nil
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        do {
            scene = try await request.scene
        } catch {
            scene = nil
        }
        isLoading = false
    }
}

struct StreetViewSheet: View {
    let coordinate: CLLocationCoordinate2D
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                StreetViewCard(coordinate: coordinate, title: title)
                    .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Street view")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StreetViewFullScreen: View {
    let scene: MKLookAroundScene
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            LookAroundViewer(scene: scene)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

private struct LookAroundViewer: UIViewControllerRepresentable {
    let scene: MKLookAroundScene
    
    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let controller = MKLookAroundViewController(scene: scene)
        controller.isNavigationEnabled = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: MKLookAroundViewController, context: Context) {
        if uiViewController.scene !== scene {
            uiViewController.scene = scene
        }
    }
}

enum StreetViewLinks {
    static func openGoogleStreetView(coordinate: CLLocationCoordinate2D) {
        let lat = coordinate.latitude
        let lng = coordinate.longitude
        guard let url = URL(string: "https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=\(lat),\(lng)") else {
            return
        }
        UIApplication.shared.open(url)
    }
}
