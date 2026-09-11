# store_app

A new Flutter project.

## Firebase

The app uses Firebase Authentication (email/password) and Firestore for company access.

Project: `stockapp-9c34c` (web, Android, iOS).

1. Enable **Email/Password** in Authentication.
2. Create a Firestore database if it does not exist.
3. Deploy rules and indexes:

```
firebase deploy --only firestore:rules,firestore:indexes --project=stockapp-9c34c
```


## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
