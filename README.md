# SpotFinder 

A skate spot finder iOS app built with SwiftUI and Firebase.

## Features

- 🔐 User authentication (login/signup)
- 🗺️ Interactive map with user location
- 📍 Add skate spots with name and comments
- 📷 Optional photo per spot (user-uploaded, stored in Firebase Storage)
- 🎯 Tap pins to view spot details
- ✏️ Long press and drag pins to reposition them
- 💾 Cloud storage with Firebase Firestore

## Tech Stack

- **SwiftUI** - Modern declarative UI framework
- **MapKit** - Map and location services
- **Firebase Auth** - User authentication
- **Firebase Firestore** - Cloud database
- **Firebase Storage** - Spot photo uploads

## Project Structure

```
Streetline/
├── Streetline/
│   ├── SpotFinderApp.swift      # App entry point
│   ├── ContentView.swift        # Main content view
│   ├── Login.swift              # Login screen
│   ├── SignUp.swift             # Sign up screen
│   ├── HomeView.swift           # Landing page after login
│   ├── MapScreen.swift          # Map with skate spots
│   ├── AddSpotView.swift        # Form to add new spots
│   ├── SpotDetailView.swift     # Detail view for spots
│   ├── SettingsView.swift       # Settings screen
│   ├── LoginViewModel.swift     # Authentication logic
│   ├── SpotService.swift        # Firebase database service
│   ├── LocationManager.swift    # Location services
│   └── SkateSpot.swift          # Data model
└── SpotFinder.xcodeproj         # Xcode project
```

## Getting Started

1. Clone the repository
2. Open `SpotFinder.xcodeproj` in Xcode
3. Configure Firebase:
   - Add your `GoogleService-Info.plist` to the project
   - Set up Firebase Authentication
   - Set up Firestore database
   - **Enable Firebase Storage** (for spot photos): Firebase Console → Build → Storage → Get started. Use test mode or set rules so authenticated users can read/write under `spotImages/`.
4. Build and run!

### Optional: Google Places (skate shops)

To show nearby skate shops on the map, add a Google Places API key. See **[GOOGLE_PLACES_SETUP.md](GOOGLE_PLACES_SETUP.md)** for steps. Spot detail photos are now user-uploaded only.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Firebase account

## Features in Detail

### Map Interaction
- **Tap a pin**: Opens detail view with spot information
- **Long press + drag**: Repositions the pin on the map
- **Add new spot**: Tap the "+" button and fill in the form

### Authentication
- Email/password authentication
- Secure session management
- Logout functionality

## License

This project is for educational purposes.

