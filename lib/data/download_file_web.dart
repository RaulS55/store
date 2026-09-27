import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> downloadBytes({
  required Uint8List bytes,
  required String filename,
  String mimeType = 'application/octet-stream',
}) async {
  if (bytes.isEmpty || filename.isEmpty) return false;
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  try {
    return _clickDownload(url: url, filename: filename);
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    web.URL.revokeObjectURL(url);
  }
}

Future<bool> downloadFromUrl({
  required String url,
  required String filename,
}) async {
  if (url.isEmpty) return false;
  return _clickDownload(url: url, filename: filename, openFallback: true);
}

bool _clickDownload({
  required String url,
  required String filename,
  bool openFallback = false,
}) {
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..rel = 'noopener';
    if (openFallback) anchor.target = '_blank';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}
