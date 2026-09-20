import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

String locationFromUri(Uri uri) {
  final fragment = uri.fragment.trim();
  if (fragment.startsWith('/')) {
    final parsed = Uri.parse(fragment);
    final path = parsed.path.trim();
    if (path.isNotEmpty) return path;
  }
  final path = uri.path.trim();
  if (path.isNotEmpty) return path;
  return '/';
}

bool isCatalogLocation(String location) {
  return location == '/catalogo' || location.startsWith('/catalogo/');
}

String appEntryLocation() {
  if (kIsWeb) return locationFromUri(Uri.base);
  final name = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  if (name.isEmpty) return '/';
  return locationFromUri(Uri.parse(name));
}
