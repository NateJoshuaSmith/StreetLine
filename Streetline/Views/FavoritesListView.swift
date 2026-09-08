//
//  FavoritesListView.swift
//  SpotFinder
//
//  List of the current user's favorited spots.
//

import SwiftUI
import FirebaseAuth
import MapKit

struct FavoritesListView: View {
    @StateObject private var spotService = SpotService()
    @StateObject private var userService = UserService()
    @State private var favoriteSpots: [SkateSpot] = []
    @State private var isLoading = true
    @State private var selectedSpot: SkateSpot?
    
    private var isLoggedIn: Bool {
        Auth.auth().currentUser != nil
    }
    
    var body: some View {
        ZStack {
            ArtBackdrop(imageName: "FavoritesBackground", dim: 0.28)
            
            Group {
                if !isLoggedIn {
                    EmptyStateCard(
                        title: "Sign in to see favorites",
                        systemImage: "heart.slash",
                        message: "Log in to save spots to your favorites list."
                    )
                } else if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.black)
                        Text("Loading favorites...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black, lineWidth: 2.5)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if favoriteSpots.isEmpty {
                    EmptyStateCard(
                        title: "No favorites yet",
                        systemImage: "heart.fill",
                        message: "Tap the heart on a spot to add it here."
                    )
                } else {
                    List {
                        ForEach(favoriteSpots) { spot in
                            HStack {
                                Spacer(minLength: 0)
                                
                                Button(action: { selectedSpot = spot }) {
                                    HStack(spacing: 12) {
                                        if let urlString = spot.imageURL ?? spot.imageURLs?.first,
                                           let url = URL(string: urlString) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                default:
                                                    Rectangle()
                                                        .fill(Color(.systemGray5))
                                                }
                                            }
                                            .frame(width: 56, height: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            ApplePlacePhotoView(
                                                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                                                width: 56,
                                                height: 56,
                                                cornerRadius: 10
                                            )
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(spot.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            if let username = spot.createdByUsername, !username.isEmpty {
                                                Text("by @\(username)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.95))
                                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                                    )
                                    .frame(maxWidth: 360)
                                }
                                .buttonStyle(.plain)
                                
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("") // custom styled title like Friends/Home
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Favorites")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.systemGray5)))
            }
        }
        .task {
            await loadFavorites()
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot, spotService: spotService)
                .onDisappear {
                    Task { await loadFavorites() }
                }
        }
    }
    
    private func loadFavorites() async {
        guard isLoggedIn else {
            isLoading = false
            return
        }
        isLoading = true
        await userService.loadFavorites()
        let ids = userService.favoriteSpotIds
        let spots = await spotService.fetchSpots(ids: ids)
        await MainActor.run {
            favoriteSpots = spots
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesListView()
    }
}
