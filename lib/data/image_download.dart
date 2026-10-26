import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'download_file.dart';
import 'download_result.dart';
import 'product_image_cache.dart';

export 'download_result.dart';

class PreparedProductImage {
  const PreparedProductImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

String productImageDownloadName(String path, {int index = 0}) {
  final fallback = 'prenda-${index + 1}.jpg';
  if (path.isEmpty) return fallback;
  final uri = Uri.tryParse(path);
  var segment = '';
  if (uri != null && uri.pathSegments.isNotEmpty) {
    segment = uri.pathSegments.last;
  } else {
    segment = path.split('/').last;
  }
  if (segment.isEmpty) return fallback;
  var name = Uri.decodeComponent(segment).split('/').last;
  name = name.split('?').first.trim();
  if (name.isEmpty || name == '.' || name == '..') return fallback;
  if (!name.contains('.')) return '$name.jpg';
  return name;
}

String productImageMimeType(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'jpg' || 'jpeg' => 'image/jpeg',
    _ => 'image/jpeg',
  };
}

Future<PreparedProductImage?> prepareProductImageDownload({
  required String path,
  Uint8List? bytes,
  ProductImageCache? cache,
  int index = 0,
}) async {
  final resolved = await resolveProductImageBytes(
    path: path,
    bytes: bytes,
    cache: cache,
  );
  if (resolved == null || resolved.isEmpty) return null;
  final filename = productImageDownloadName(path, index: index);
  final mimeType = productImageMimeType(filename);
  final adapted = adaptImageForDeviceGallery(
    bytes: resolved,
    filename: filename,
    mimeType: mimeType,
  );
  return PreparedProductImage(
    bytes: adapted.bytes,
    filename: adapted.filename,
    mimeType: adapted.mimeType,
  );
}

Future<ImageDownloadResult> saveProductImageBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  bool allowGesturePrompt = true,
}) {
  return saveImageBytes(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
    allowGesturePrompt: allowGesturePrompt,
  );
}

Future<ImageDownloadResult> downloadProductImage({
  required String path,
  Uint8List? bytes,
  ProductImageCache? cache,
  int index = 0,
}) {
  final filename = productImageDownloadName(path, index: index);
  final mimeType = productImageMimeType(filename);
  final immediate = _immediateBytes(path: path, bytes: bytes, cache: cache);
  if (immediate != null) {
    final adapted = adaptImageForDeviceGallery(
      bytes: immediate,
      filename: filename,
      mimeType: mimeType,
    );
    return saveImageBytes(
      bytes: adapted.bytes,
      filename: adapted.filename,
      mimeType: adapted.mimeType,
    );
  }
  return _downloadResolvedProductImage(
    path: path,
    bytes: bytes,
    cache: cache,
    filename: filename,
    mimeType: mimeType,
  );
}

Uint8List? _immediateBytes({
  required String path,
  Uint8List? bytes,
  ProductImageCache? cache,
}) {
  if (bytes != null && bytes.isNotEmpty) return bytes;
  final peeked = cache?.peek(path);
  if (peeked != null && peeked.isNotEmpty) return peeked;
  return null;
}

Future<ImageDownloadResult> _downloadResolvedProductImage({
  required String path,
  Uint8List? bytes,
  ProductImageCache? cache,
  required String filename,
  required String mimeType,
}) async {
  final resolved = await resolveProductImageBytes(
    path: path,
    bytes: bytes,
    cache: cache,
  );
  if (resolved != null && resolved.isNotEmpty) {
    final adapted = adaptImageForDeviceGallery(
      bytes: resolved,
      filename: filename,
      mimeType: mimeType,
    );
    return saveImageBytes(
      bytes: adapted.bytes,
      filename: adapted.filename,
      mimeType: adapted.mimeType,
    );
  }
  if (isNetworkProductImageUrl(path)) {
    return downloadImageUrl(url: path, filename: filename, mimeType: mimeType);
  }
  return const ImageDownloadResult.failed();
}

Future<Uint8List?> resolveProductImageBytes({
  required String path,
  Uint8List? bytes,
  ProductImageCache? cache,
}) async {
  if (bytes != null && bytes.isNotEmpty) return bytes;
  final peeked = cache?.peek(path);
  if (peeked != null && peeked.isNotEmpty) return peeked;
  if (isNetworkProductImageUrl(path)) {
    if (cache != null && cache.allowRemoteFetch) {
      final loaded = await cache.load(path);
      if (loaded != null && loaded.isNotEmpty) return loaded;
    }
    try {
      return await fetchProductImageBytes(path);
    } catch (error) {
      debugPrint('Image download fetch failed: $path $error');
      return null;
    }
  }
  if (path.startsWith('assets/')) {
    try {
      final data = await rootBundle.load(path);
      final viewed = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return viewed.isEmpty ? null : viewed;
    } catch (error) {
      debugPrint('Image download asset failed: $path $error');
      return null;
    }
  }
  return null;
}
