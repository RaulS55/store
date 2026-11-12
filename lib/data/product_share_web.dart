import 'dart:js_interop';

import 'package:web/web.dart';

/// Opens the browser share sheet in the same turn as the tap.
///
/// Returns null when this browser cannot share, so the caller can copy while
/// the tap is still active. A completed or dismissed sheet returns true.
/// share_plus checks `canShare` and awaits before calling `navigator.share`,
/// which mobile browsers reject for plain text.
Future<bool>? startWebShare(String text, String url) {
  final navigator = window.navigator;
  final textAndUrl = ShareData(text: text, url: url);
  final textOnly = ShareData(text: text);
  final urlOnly = ShareData(url: url);
  ShareData? supported;
  for (final data in [textAndUrl, textOnly, urlOnly]) {
    try {
      if (navigator.canShare(data)) {
        supported = data;
        break;
      }
    } catch (_) {
      break;
    }
  }
  final chosen = supported ?? textOnly;
  try {
    return _finish(navigator.share(chosen));
  } catch (_) {
    if (identical(chosen, urlOnly)) return null;
    try {
      return _finish(navigator.share(urlOnly));
    } catch (_) {
      return null;
    }
  }
}

Future<bool> _finish(JSPromise<JSAny?> pending) async {
  try {
    await pending.toDart;
    return true;
  } catch (error) {
    if (error.isA<DOMException>() &&
        (error as DOMException).name == 'AbortError') {
      return true;
    }
    return false;
  }
}
