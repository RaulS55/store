import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> copyToClipboard(String text) async {
  if (text.isEmpty) return false;
  try {
    await web.window.navigator.clipboard.writeText(text).toDart;
    return true;
  } catch (_) {
    return _copyWithExecCommand(text);
  }
}

bool _copyWithExecCommand(String text) {
  final body = web.document.body;
  if (body == null) return false;
  final textarea = web.HTMLTextAreaElement()
    ..value = text
    ..readOnly = true;
  textarea.style
    ..position = 'fixed'
    ..left = '-9999px'
    ..top = '0'
    ..opacity = '0';
  try {
    body.append(textarea);
    textarea.focus();
    textarea.select();
    textarea.setSelectionRange(0, text.length);
    return web.document.execCommand('copy');
  } catch (_) {
    return false;
  } finally {
    textarea.remove();
  }
}
