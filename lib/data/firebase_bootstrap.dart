import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

Future<void> configureFirebaseForPlatform() async {
  if (!kIsWeb) return;
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      webExperimentalForceLongPolling: true,
      webExperimentalAutoDetectLongPolling: false,
    );
  } catch (_) {}
  try {
    await FirebaseAuth.instance
        .setPersistence(Persistence.LOCAL)
        .timeout(const Duration(seconds: 2));
  } catch (_) {}
}
