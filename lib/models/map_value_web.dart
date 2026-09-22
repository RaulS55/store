import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:js_util' as js_util;

@JS('Object.keys')
external JSArray<JSString> _objectKeys(JSObject object);

@JS('Array.isArray')
external bool _arrayIsArray(JSAny? value);

@JS('JSON.stringify')
external JSString? _jsonStringify(JSAny? value);

/// Converts a Firestore/Hive JS object into a real Dart map.
///
/// DDC exposes those snapshots as [LegacyJavaScriptObject]. That type is not
/// a Dart [Map] and cannot be cast to [JSAny], so [dartify] / [objectKeys]
/// have to run before any `as JSAny` conversion.
Map<String, dynamic>? plainJsMap(Object? value) {
  if (value == null) return null;
  final object = value;
  if (object is String ||
      object is num ||
      object is bool ||
      object is DateTime ||
      object is List) {
    return null;
  }
  try {
    final converted = _normalize(js_util.dartify(object));
    if (converted is Map<String, dynamic>) return converted;
    if (converted is Map) return _asStringKeyMap(converted);
  } catch (_) {}
  try {
    return {
      for (final key in js_util.objectKeys(object))
        if (key != null)
          '$key': _normalize(js_util.dartify(js_util.getProperty(object, key))),
    };
  } catch (_) {}
  try {
    final js = _asJsAny(object);
    if (js == null) return null;
    final converted = _jsToDart(js);
    if (converted is Map<String, dynamic>) return converted;
    if (converted is Map) return _asStringKeyMap(converted);
    final encoded = _jsonStringify(js)?.toDart;
    if (encoded == null || encoded.isEmpty || encoded == 'null') return null;
    final decoded = jsonDecode(encoded);
    if (decoded is Map) return _asStringKeyMap(decoded);
  } catch (_) {}
  return null;
}

JSAny? _asJsAny(Object value) {
  if (value is JSAny) return value;
  try {
    return value as JSAny;
  } catch (_) {
    try {
      return js_util.jsify(value) as JSAny?;
    } catch (_) {
      return null;
    }
  }
}

dynamic _jsToDart(JSAny? value) {
  if (value == null || value.isUndefinedOrNull) return null;
  if (value.isA<JSString>()) return (value as JSString).toDart;
  if (value.isA<JSBoolean>()) return (value as JSBoolean).toDart;
  if (value.isA<JSNumber>()) return (value as JSNumber).toDartDouble;
  if (_arrayIsArray(value)) {
    return [for (final item in (value as JSArray).toDart) _jsToDart(item)];
  }
  if (value.isA<JSObject>()) {
    final object = value as JSObject;
    return <String, dynamic>{
      for (final key in _objectKeys(object).toDart)
        key.toDart: _jsToDart(object.getProperty(key)),
    };
  }
  return null;
}

Map<String, dynamic> _asStringKeyMap(Map<dynamic, dynamic> map) {
  return {
    for (final entry in map.entries) '${entry.key}': _normalize(entry.value),
  };
}

dynamic _normalize(dynamic value) {
  if (value == null ||
      value is String ||
      value is num ||
      value is bool ||
      value is DateTime) {
    return value;
  }
  if (value is Map) return _asStringKeyMap(value);
  if (value is List) return [for (final item in value) _normalize(item)];
  return value;
}
