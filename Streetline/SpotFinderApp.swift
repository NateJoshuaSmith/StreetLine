//
//  SpotFinderApp.swift
//  SpotFinder
//
//  Created by Nathan Smith on 11/20/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct SpotFinderApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var viewModel = LoginViewModel()
    @StateObject private var activityService = ActivityService()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                if viewModel.isLoggedIn {
                    if viewModel.needsUsernameSetup {
                        SetUsernameView()
                    } else {
                        HomeView()
                    }
                } else {
                    Login()
                }
            }
            .navigationViewStyle(.stack)
            .background(Color.black.ignoresSafeArea())
            .environmentObject(viewModel)
            .environmentObject(activityService)
            .onChange(of: viewModel.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn, !viewModel.needsUsernameSetup {
                    activityService.startListening()
                } else {
                    activityService.stopListening()
                }
            }
            .onChange(of: viewModel.needsUsernameSetup) { _, needsUsername in
                if viewModel.isLoggedIn, !needsUsername {
                    activityService.startListening()
                }
            }
            .onAppear {
                if viewModel.isLoggedIn, !viewModel.needsUsernameSetup {
                    activityService.startListening()
                }
            }
        }
    }
}
