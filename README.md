# Streetline

Streetline is an iOS skate-spot app for finding, sharing, and talking about places to skate. Sign in, drop pins on a map, rate and comment on spots, save favorites, add friends, and post when you are looking for a session.

Built with SwiftUI, MapKit, and Firebase.

## Features

- Email/password accounts with usernames and profile photos
- Interactive map of community skate spots
- Add spots with photos, tags, difficulty, and fun level
- Spot details: ratings, comments, photos, directions, and reports
- Favorites list
- Friends, friend requests, and 1:1 chat
- Community posts for finding people to skate with
- Nearby skate shops and skate parks
- Settings, username/avatar edits, and contact support

## How the app works

### Accounts and login

Open the app on the login screen. Sign in with email and password, or open **Sign Up** to create an account. Sign up requires a username, email, password, and password confirmation.

After login, Streetline looks up your profile in Firestore:

- New accounts get a profile during sign up.
- Older accounts without a username are sent to a **Choose a username** screen before home.
- Logout is in the home screen wrench menu. It signs you out of Firebase Auth and clears the cached friends list.

Your username is what other people see on spots, comments, posts, and profiles.

### Home

Home is the hub after you log in. The top bar has:

- **Friends** — your friends list, incoming requests, and pending outgoing requests
- **Wrench menu** — Settings or Logout

Three tiles open the main areas of the app:

| Tile | Opens |
| --- | --- |
| **MAP** | Community skate-spot map |
| **POSTS** | Community board (“looking to skate”) |
| **FAVORITES** | Spots you have hearted |

### Map

The map loads skate spots from Firestore and centers on your location when location permission is granted (otherwise it starts near San Francisco).

**Pins**

- Tap a pin to open a preview card (photo, name, description snippet, rating, tags, difficulty, fun level).
- **Open** opens the full spot sheet.
- **Directions** opens Apple Maps.
- The heart on the card saves or removes the spot from favorites.
- Your own spots can be moved: long-press, then drag. The new coordinates are saved to Firestore. Other people’s pins cannot be moved.

**Add a spot**

1. Pan the map so the center sits on the place you want to mark.
2. Tap **+**.
3. Fill in a name and description.
4. Optionally add a photo from your library (uploaded to Firebase Storage).
5. Pick tags, difficulty, and fun level.
6. Save. The spot is stored in Firestore with your user ID and username.

Tags: Street, Park, DIY, Ledge, Rail, Hubba, Bowl, Red Curb  
Difficulty: Beginner, Intermediate, Advanced  
Fun level: Not fun but skateable, Fun, Super Fun

**Filters**

The filter bar hides pins that do not match the selected tag, difficulty, and/or fun level. Choose **All tags**, **Any level**, or **Any fun** to clear a filter.

**Map shortcuts**

- Friends list
- Nearby skate shops
- Nearby skate parks
- Favorites

### Spot details

The spot sheet is the full page for one pin.

- **Photos** — swipe through uploaded photos. The spot owner can add or delete photos.
- **Favorite** — heart in the toolbar.
- **Rating** — 1–5 stars. The average and count come from a Firestore `ratings` subcollection. You can change your rating later.
- **Description, tags, difficulty, fun level** — set when the spot was created.
- **Directions** — opens turn-by-turn directions in Apple Maps.
- **Creator** — tap `@username` to open that person’s profile.
- **Comments** — real-time thread on the spot. You can like or dislike a comment (one or the other).
- **Report** — flag a spot as inappropriate, spam, wrong location, offensive, or other. Reports go to a Firestore `reports` collection.
- **Delete Spot** — only the owner can delete the pin (and its stored photos).

### Favorites

From Home or the map, open **Favorites** to see every spot you have hearted. Tap a row to open that spot’s detail sheet. Heart a spot again (on the map card or detail page) to remove it.

Favorites are stored on your user profile in Firestore, not only on the device.

### Friends and chat

Open **Friends** from Home or the map.

- **Requests** — accept or decline incoming friend requests.
- **Friends** — tap a friend to open their profile, or remove them. You can also start a chat from their profile.
- **Pending** — outgoing requests you have sent.
- **Add friend** — search by username prefix and send a request.

Profiles show avatar, username, join date, recent community posts, and spots that person added. From someone else’s profile you can message them or send a friend request.

**Chat** is a 1:1 thread. Opening a conversation creates or reuses a thread in Firestore and listens for new messages in real time.

### Community posts

**Posts** is a live board for “looking to skate” messages.

- Tap **+** to write a post.
- The list updates in real time.
- Tap a post to read it and reply.
- Tap `@username` on a post to open that profile.

Posts and replies are stored in Firestore and attributed to your username.

### Nearby shops and parks

From the map, open the storefront or skateboarding icons.

- **Skate shops** — Google Places search around the current map center (about 10 km). Tap a result for directions in Apple Maps.
- **Skate parks** — same Places search for parks, plus a **User Pins** tab that lists Streetline spots in the area.

These lists need a Google Places API key in the app Info plist (`GooglePlacesAPIKey`). Without a key, the lists stay empty.

### Settings and support

Settings (home wrench menu) shows your avatar, `@username`, and email.

- Tap the photo to upload a new avatar (Firebase Storage).
- **Change username** updates the name stored on your profile.
- **Contact Support** opens a form. Subject and message are required; **Open in Mail** drafts an email that includes the app version. You can also copy the support address.

## Tech stack

- **SwiftUI** — UI and navigation
- **MapKit** — map, camera, and Apple Maps directions
- **Core Location** — user location
- **Firebase Auth** — email/password accounts
- **Cloud Firestore** — spots, profiles, friends, chats, community posts, comments, ratings, reports
- **Firebase Storage** — spot photos and avatars
- **Google Places API (New)** — optional nearby shops and parks

## Project structure

```
Streetline/
├── Streetline/
│   ├── SpotFinderApp.swift      # App entry, login vs home vs username setup
│   ├── Info.plist               # Google Places key (optional)
│   ├── Models/                  # Spot, user, message, post, report types
│   ├── Views/                   # Screens (map, home, friends, community, …)
│   ├── ViewModels/              # Login / session
│   └── Services/                # Firebase, location, Places
└── SpotFinder.xcodeproj
```

## Getting started

1. Clone the repository.
2. Open `SpotFinder.xcodeproj` in Xcode.
3. Configure Firebase:
   - Add `GoogleService-Info.plist` to the app target.
   - Enable Email/Password in Authentication.
   - Create a Firestore database.
   - Enable Storage so signed-in users can read/write spot images and avatars.
4. (Optional) Add a Google Places API key as `GooglePlacesAPIKey` in the target Info settings, restricted to the Places API and this iOS app. That powers nearby shops and parks.
5. Build and run on a simulator or device. Location features work best on a device.

## Requirements

- Xcode 15 or later
- iOS 17 or later
- Firebase project (Auth, Firestore, Storage)
- Google Cloud Places API key (optional, for nearby shops and parks)
