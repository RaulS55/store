import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

const customAppHost = 'app.modastore.org';

FirebaseOptions firebaseOptionsForHost({Uri? uri, bool? isWeb}) {
  if (!(isWeb ?? kIsWeb)) {
    return DefaultFirebaseOptions.currentPlatform;
  }
  final options = DefaultFirebaseOptions.web;
  final host = (uri ?? Uri.base).host;
  if (host == customAppHost) {
    return options.copyWith(authDomain: host);
  }
  return options;
}

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
