import 'dart:convert';

import 'map_value_web.dart' if (dart.library.io) 'map_value_stub.dart';

/// Copies [value] into a real Dart [Map].
///
/// On web, Firestore snapshots and Hive boxes can yield JS objects that are
/// typed as [Map] but do not implement Dart's `[]` (`map[$_get] is not a
/// function`). A fresh [LinkedHashMap] avoids that.
Map<String, dynamic> coerceStringKeyMap(Object? value) {
  if (value == null) {
    throw FormatException('Expected map, got null');
  }
  final fromJs = plainJsMap(value);
  if (fromJs != null) return fromJs;
  if (value is Map) {
    try {
      return _copyMap(value);
    } catch (_) {}
  }
  final viaJson = _tryJsonMap(value);
  if (viaJson != null) return viaJson;
  throw FormatException('Expected map, got ${value.runtimeType}');
}

Map<String, dynamic>? tryCoerceStringKeyMap(Object? value) {
  if (value == null) return null;
  try {
    return coerceStringKeyMap(value);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? decodeCatalogMap(Object? raw) {
  if (raw == null) return null;
  if (raw is String) {
    if (raw.isEmpty) return null;
    return tryCoerceStringKeyMap(jsonDecode(raw));
  }
  return tryCoerceStringKeyMap(raw);
}

String encodeCatalogMap(Map<String, dynamic> map) {
  return jsonEncode(coerceStringKeyMap(map));
}

Map<String, dynamic>? _tryJsonMap(Object? value) {
  try {
    final decoded = jsonDecode(jsonEncode(value));
    if (decoded is Map) return _copyMap(decoded);
  } catch (_) {}
  return null;
}

Map<String, dynamic> _copyMap(Map<dynamic, dynamic> map) {
  final result = <String, dynamic>{};
  map.forEach((key, value) {
    result['$key'] = _copyValue(value);
  });
  return result;
}

dynamic _copyValue(dynamic value) {
  if (value is Map) return _copyMap(value);
  if (value is List) return [for (final item in value) _copyValue(item)];
  final fromJs = plainJsMap(value);
  if (fromJs != null) return fromJs;
  return value;
}
