import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

void configureFirebaseForPlatform() {
  if (!kIsWeb) return;
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    webExperimentalAutoDetectLongPolling: true,
  );
}
