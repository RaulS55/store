import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Object.keys')
external JSArray<JSString> _objectKeys(JSObject object);

@JS('Array.isArray')
external bool _arrayIsArray(JSAny? value);

/// Converts a Firestore/Hive JS object into a real Dart map.
///
/// Used when the value is typed as [Map] but `[]` is not implemented
/// (`map[$_get] is not a function` on web).
Map<String, dynamic>? plainJsMap(Object? value) {
  if (value == null) return null;
  try {
    final converted = _jsToDart(value as JSAny);
    if (converted is Map<String, dynamic>) return converted;
    if (converted is Map) {
      return {
        for (final entry in converted.entries) '${entry.key}': entry.value,
      };
    }
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
    final object = value as JSObject;
    return <String, dynamic>{
      for (final key in _objectKeys(object).toDart)
        key.toDart: _jsToDart(object.getProperty(key)),
    };
  }
  return null;
}
