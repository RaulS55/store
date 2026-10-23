import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Object.keys')
external JSArray<JSString> _objectKeys(JSObject object);

@JS('Array.isArray')
external bool _arrayIsArray(JSAny? value);

@JS('JSON.stringify')
external JSString? _jsonStringify(JSAny? value);

/// Converts a Firestore/Hive JS object into a real Dart map.
///
/// DDC exposes those snapshots as legacy JS objects. They are not a Dart
/// [Map], so wrap them with [JSObject.fromInteropObject] before [dartify].
Map<String, dynamic>? plainJsMap(Object? value) {
  if (value == null) return null;
  if (value is String ||
      value is num ||
      value is bool ||
      value is DateTime ||
      value is List) {
    return null;
  }
  final object = _asJsObject(value);
  if (object == null) return null;
  try {
    final converted = _normalize(object.dartify());
    if (converted is Map<String, dynamic>) return converted;
    if (converted is Map) return _asStringKeyMap(converted);
  } catch (_) {}
  try {
    return {
      for (final key in _objectKeys(object).toDart)
        key.toDart: _normalize(object.getProperty<JSAny?>(key).dartify()),
    };
  } catch (_) {}
  try {
    final converted = _jsToDart(object);
    if (converted is Map<String, dynamic>) return converted;
    if (converted is Map) return _asStringKeyMap(converted);
    final encoded = _jsonStringify(object)?.toDart;
    if (encoded == null || encoded.isEmpty || encoded == 'null') return null;
    final decoded = jsonDecode(encoded);
    if (decoded is Map) return _asStringKeyMap(decoded);
  } catch (_) {}
  return null;
}

JSObject? _asJsObject(Object value) {
  try {
    if (value.isA<JSObject>()) return value as JSObject;
  } catch (_) {}
  try {
    return JSObject.fromInteropObject(value);
  } catch (_) {}
  try {
    final js = value.jsify();
    if (js.isA<JSObject>()) return js as JSObject;
  } catch (_) {}
  return null;
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
    final date = _jsTimestampToDate(value);
    if (date != null) return date;
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

/// Firestore `Timestamp` is a JS class. `dartify` leaves it as-is, and a
/// release build cannot call `.toDate()` through `dynamic`.
DateTime? _jsTimestampToDate(Object? value) {
  if (value == null ||
      value is DateTime ||
      value is String ||
      value is num ||
      value is bool ||
      value is List ||
      value is Map) {
    return null;
  }
  final object = _asJsObject(value);
  if (object == null) return null;
  try {
    if (object.has('toMillis')) {
      final millis = object.callMethod<JSAny?>('toMillis'.toJS).dartify();
      if (millis is num) {
        return DateTime.fromMillisecondsSinceEpoch(millis.round(), isUtc: true);
      }
    }
  } catch (_) {}
  try {
    if (!object.has('toDate')) return null;
    final date = object.callMethod<JSAny?>('toDate'.toJS).dartify();
    if (date is DateTime) return date.toUtc();
  } catch (_) {}
  return null;
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
  final date = _jsTimestampToDate(value);
  if (date != null) return date;
  return value;
}
