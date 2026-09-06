//
//  HomeView.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: LoginViewModel
    @EnvironmentObject var activityService: ActivityService
    @State private var showSettings: Bool = false
    
    var body: some View {
        let showFriendsDot = activityService.homeBadgeCount > 0
        return ZStack {
            Image("CityImage")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 32)
                        
                        menuBar
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.always)
            }
            
            VStack(spacing: 0) {
                Image("UpdatedLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    .padding(.top, 62)
                    .accessibilityLabel("SpotFinder")
                    .allowsHitTesting(false)
                
                Spacer(minLength: 0)
            }
            .ignoresSafeArea(edges: .top)
            
            VStack {
                HStack(spacing: 6) {
                    NavigationLink(destination: FriendsListView()) {
                        Label("Friends", systemImage: "person.2.fill")
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(toolbarCapsule)
                    }
                    if showFriendsDot {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "wrench.fill")
                        }
                        
                        Button(role: .destructive) {
                            Task {
                                await viewModel.logout()
                            }
                        } label: {
                            Label("Logout", systemImage: "arrow.right.square.fill")
                        }
                    } label: {
                        Label("Settings", systemImage: "wrench.fill")
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(toolbarCapsule)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .background(
            NavigationLink(
                destination: SettingsView(),
                isActive: $showSettings,
                label: { EmptyView() }
            )
            .hidden()
        )
        .onAppear {
            activityService.startListening()
        }
    }
    
    private var toolbarCapsule: some View {
        ZStack {
            Capsule().fill(Color.white.opacity(0.92))
            Capsule().strokeBorder(Color.black, lineWidth: 2.5)
        }
    }
    
    private var menuBar: some View {
        VStack(spacing: 14) {
            Text("Discover and share skate spots")
                .font(.subheadline.weight(.heavy))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                homeActionTile(
                    title: "MAP",
                    systemImage: "map.fill",
                    destination: MapScreen(),
                    fill: Color(red: 0.22, green: 0.58, blue: 1.0)
                )
                
                homeActionTile(
                    title: "POSTS",
                    systemImage: "person.3.fill",
                    destination: CommunityForumView(),
                    fill: Color(red: 0.93, green: 0.18, blue: 0.58)
                )
                
                homeActionTile(
                    title: "FAVORITES",
                    systemImage: "heart.fill",
                    destination: FavoritesListView(),
                    fill: Color(red: 1.0, green: 0.62, blue: 0.12)
                )
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
    }
    
    private func homeActionTile<Destination: View>(
        title: String,
        systemImage: String,
        destination: Destination,
        fill: Color
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.heavy))
                Text(title)
                    .font(.caption.weight(.heavy))
                    .tracking(0.4)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationView {
        HomeView()
            .environmentObject(LoginViewModel())
            .environmentObject(ActivityService())
    }
}
