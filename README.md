# Chatting App

A real-time one-to-one chat app built with Flutter and Firebase.

## Features
- Email/password registration, login, logout and password reset
- User profiles with editable name and profile picture
- Search users by name
- Real-time one-to-one messaging
- Chat list with last-message preview and unread counters
- Read receipts (sent / seen ticks)
- Online / offline status and "last seen"
- Image sharing in chats (Cloudinary)
- In-app message notifications (app open or in background)

## Tech Stack
- Flutter / Dart
- Firebase Authentication
- Cloud Firestore
- Cloudinary (image hosting, free tier)

## Setup
1. Install Flutter and the Firebase CLI.
2. Create a Firebase project and run `flutterfire configure`.
3. Enable Email/Password in Firebase Authentication.
4. Create a Firestore database and publish the rules in `firestore.rules`.
5. In `lib/services/storage_service.dart`, set your Cloudinary cloud name
   and an unsigned upload preset.
6. Run:

   flutter pub get
   flutter run

## Project Structure
- `lib/models/` data classes
- `lib/services/` Firebase, Cloudinary and notification code
- `lib/features/` screens grouped by feature (auth, chats, contacts, profile)
- `lib/common/` shared widgets

## Limitations
- Notifications do not reach a fully closed app (that needs Cloud Functions
  and Firebase's paid plan).
- User search matches names that start with the typed text.