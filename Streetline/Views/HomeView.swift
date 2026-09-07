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
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HomeCityBackdrop(date: context.date)
            }
            
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
                    .accessibilityLabel("Streetline")
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
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(toolbarCapsule)
            
            HStack(spacing: 12) {
                homeActionTile(
                    title: "MAP",
                    systemImage: "map.fill",
                    destination: MapScreen(),
                    fill: Color(red: 0.22, green: 0.58, blue: 1.0)
                )
                
                homeActionTile(
                    title: "SKATE WITH",
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
            
            NavigationLink(destination: LobbyView()) {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3.weight(.heavy))
                    Text("LOBBY")
                        .font(.caption.weight(.heavy))
                        .tracking(0.4)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.12, green: 0.76, blue: 0.48))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 3)
                )
            }
            .buttonStyle(.plain)
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

private struct HomeCityBackdrop: View {
    let date: Date
    
    var body: some View {
        let sky = HomeSky.current(at: date)
        ZStack {
            Image("CityImage")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .colorMultiply(sky.multiply)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: sky.overlay,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

private enum HomeSky {
    case morning, afternoon, evening, night
    
    static func current(at date: Date) -> HomeSky {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: return .morning
        case 11..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
    
    var multiply: Color {
        switch self {
        case .morning: return Color(red: 1.0, green: 0.93, blue: 0.82)
        case .afternoon: return .white
        case .evening: return Color(red: 1.0, green: 0.78, blue: 0.62)
        case .night: return Color(red: 0.48, green: 0.55, blue: 0.78)
        }
    }
    
    var overlay: [Color] {
        switch self {
        case .morning:
            return [
                Color.orange.opacity(0.18),
                Color.yellow.opacity(0.06),
                Color.black.opacity(0.38)
            ]
        case .afternoon:
            return [
                Color.black.opacity(0.12),
                Color.black.opacity(0.08),
                Color.black.opacity(0.45)
            ]
        case .evening:
            return [
                Color.orange.opacity(0.28),
                Color.purple.opacity(0.18),
                Color.black.opacity(0.52)
            ]
        case .night:
            return [
                Color(red: 0.05, green: 0.08, blue: 0.22).opacity(0.45),
                Color.black.opacity(0.28),
                Color.black.opacity(0.62)
            ]
        }
    }
}

#Preview {
    NavigationView {
        HomeView()
            .environmentObject(LoginViewModel())
            .environmentObject(ActivityService())
    }
}
