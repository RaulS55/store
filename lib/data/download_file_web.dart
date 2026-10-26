import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:web/web.dart' as web;

import 'download_result.dart';

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

({Uint8List bytes, String filename, String mimeType})
adaptImageForDeviceGallery({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  if (!_shareImagesToGallery()) {
    return (bytes: bytes, filename: filename, mimeType: mimeType);
  }
  if (mimeType == 'image/jpeg' ||
      mimeType == 'image/png' ||
      mimeType == 'image/gif') {
    return (bytes: bytes, filename: filename, mimeType: mimeType);
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return (bytes: bytes, filename: filename, mimeType: mimeType);
  }
  final dot = filename.lastIndexOf('.');
  final jpegName = dot <= 0
      ? '$filename.jpg'
      : '${filename.substring(0, dot)}.jpg';
  return (
    bytes: img.encodeJpg(decoded, quality: 90),
    filename: jpegName,
    mimeType: 'image/jpeg',
  );
}

Future<ImageDownloadResult> saveImageBytes({
  required Uint8List bytes,
  required String filename,
  String mimeType = 'image/jpeg',
  bool allowGesturePrompt = true,
}) {
  final shared = _startGalleryShare(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
    allowGesturePrompt: allowGesturePrompt,
  );
  if (shared != null) return shared;
  return _downloadImageFile(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );
}

Future<ImageDownloadResult> _downloadImageFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final ok = await downloadBytes(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );
  if (!ok) return const ImageDownloadResult.failed();
  return const ImageDownloadResult.downloaded();
}

bool _shareImagesToGallery() {
  final navigator = web.window.navigator;
  return isMobileWebUserAgent(
    navigator.userAgent,
    maxTouchPoints: navigator.maxTouchPoints,
  );
}

/// Phones block websites from writing the photo library. Sharing the file is
/// what shows "Guardar imagen" on iOS and the gallery apps on Android.
Future<ImageDownloadResult>? _startGalleryShare({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  required bool allowGesturePrompt,
}) {
  if (!_shareImagesToGallery() || !mimeType.startsWith('image/')) return null;
  final safeName = filename.replaceAll(RegExp(r'[/\\]'), '_');
  try {
    final file = web.File(
      [bytes.toJS].toJS,
      safeName,
      web.FilePropertyBag(type: mimeType),
    );
    final files = [file].toJS;
    final navigator = web.window.navigator;
    final withTitle = web.ShareData(
      files: files,
      title: 'Guardar en la galería',
    );
    final web.ShareData data;
    if (navigator.canShare(withTitle)) {
      data = withTitle;
    } else {
      final filesOnly = web.ShareData(files: files);
      if (!navigator.canShare(filesOnly)) return null;
      data = filesOnly;
    }
    return _finishShare(
      navigator.share(data).toDart,
      bytes: bytes,
      filename: safeName,
      mimeType: mimeType,
      allowGesturePrompt: allowGesturePrompt,
    );
  } catch (error) {
    debugPrint('Image gallery share unavailable: $error');
    return null;
  }
}

Future<ImageDownloadResult> _finishShare(
  Future<JSAny?> shared, {
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  required bool allowGesturePrompt,
}) async {
  try {
    await shared;
    return const ImageDownloadResult.gallery();
  } catch (error) {
    final name = _shareErrorName(error);
    if (name == 'AbortError') return const ImageDownloadResult.cancelled();
    if (name == 'NotAllowedError' && allowGesturePrompt) {
      return ImageDownloadResult.needsGesture(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
    }
    debugPrint('Image gallery share failed: $error');
  }
  return _downloadImageFile(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );
}

Future<ImageDownloadResult> downloadImageUrl({
  required String url,
  required String filename,
  required String mimeType,
}) async {
  final bytes = await _fetchUrlBytes(url);
  if (bytes == null || bytes.isEmpty) return const ImageDownloadResult.failed();
  return saveImageBytes(bytes: bytes, filename: filename, mimeType: mimeType);
}

Future<bool> downloadFromUrl({
  required String url,
  required String filename,
}) async {
  if (url.isEmpty || filename.isEmpty) return false;
  final saved = await downloadImageUrl(
    url: url,
    filename: filename,
    mimeType: _mimeForFilename(filename),
  );
  return saved.status == ImageSaveStatus.downloaded ||
      saved.status == ImageSaveStatus.gallery;
}

Future<Uint8List?> _fetchUrlBytes(String url) async {
  if (url.isEmpty) return null;
  try {
    final response = await web.window.fetch(url.toJS).toDart;
    if (!response.ok) {
      debugPrint('Image URL fetch failed: ${response.status} $url');
      return null;
    }
    final buffer = (await response.arrayBuffer().toDart).toDart;
    final bytes = buffer.asUint8List();
    return bytes.isEmpty ? null : bytes;
  } catch (error) {
    debugPrint('Image URL fetch failed: $url $error');
    return null;
  }
}

String _mimeForFilename(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'jpg' || 'jpeg' => 'image/jpeg',
    _ => 'image/jpeg',
  };
}

String? _shareErrorName(Object error) {
  try {
    if (error.isA<web.DOMException>()) {
      return (error as web.DOMException).name;
    }
  } catch (_) {}
  final text = '$error';
  if (text.contains('AbortError')) return 'AbortError';
  if (text.contains('NotAllowedError')) return 'NotAllowedError';
  return null;
}

bool _clickDownload({required String url, required String filename}) {
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..rel = 'noopener';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}
