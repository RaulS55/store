import 'package:web/web.dart' as web;

String? readWebEncryptionKey(String name) {
  try {
    final value = web.window.localStorage.getItem(name);
    if (value == null || value.isEmpty) return null;
    return value;
  } catch (_) {
    return null;
  }
}

void writeWebEncryptionKey(String name, String value) {
  try {
    web.window.localStorage.setItem(name, value);
  } catch (_) {}
}
