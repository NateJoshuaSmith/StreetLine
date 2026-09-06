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
        }
    }
}
