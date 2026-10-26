import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/image_download.dart';
import 'package:store_app/data/product_image_cache.dart';

void main() {
  test('names a missing path with a fallback', () {
    expect(productImageDownloadName(''), 'prenda-1.jpg');
    expect(productImageDownloadName('', index: 2), 'prenda-3.jpg');
  });

  test('keeps the file name from a storage URL', () {
    expect(
      productImageDownloadName(
        'https://firebasestorage.googleapis.com/v0/b/x/o/products%2Fabc%2Ffoto.png?alt=media&token=1',
      ),
      'foto.png',
    );
  });

  test('adds an extension when the path has none', () {
    expect(
      productImageDownloadName('https://cdn.example.com/img/uuid', index: 2),
      'uuid.jpg',
    );
  });

  test('keeps an asset file name', () {
    expect(productImageDownloadName('assets/products/demo.jpg'), 'demo.jpg');
  });

  test('maps common image extensions to mime types', () {
    expect(productImageMimeType('foto.png'), 'image/png');
    expect(productImageMimeType('foto.WEBP'), 'image/webp');
    expect(productImageMimeType('foto'), 'image/jpeg');
  });

  test('resolves bytes from the entry or the cache', () async {
    final cache = ProductImageCache(allowRemoteFetch: false);
    await cache.put('https://example.com/a.jpg', Uint8List.fromList([1, 2, 3]));

    expect(
      await resolveProductImageBytes(
        path: 'https://example.com/a.jpg',
        bytes: Uint8List.fromList([9]),
        cache: cache,
      ),
      Uint8List.fromList([9]),
    );
    expect(
      await resolveProductImageBytes(
        path: 'https://example.com/a.jpg',
        cache: cache,
      ),
      Uint8List.fromList([1, 2, 3]),
    );
  });

  test('prepares a named file from bytes already in memory', () async {
    final prepared = await prepareProductImageDownload(
      path: 'https://cdn.example.com/foto.png',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(prepared?.filename, 'foto.png');
    expect(prepared?.mimeType, 'image/png');
    expect(prepared?.bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('detects phone browsers that can save into the gallery', () {
    expect(
      isMobileWebUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
      ),
      isTrue,
    );
    expect(
      isMobileWebUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 7)'),
      isTrue,
    );
    expect(
      isMobileWebUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
        maxTouchPoints: 5,
      ),
      isTrue,
    );
    expect(
      isMobileWebUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'),
      isFalse,
    );
    expect(
      isMobileWebUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64)'),
      isFalse,
    );
  });

  test('gallery and download results use different messages', () {
    expect(
      const ImageDownloadResult.gallery().message,
      'Imagen guardada en la galería.',
    );
    expect(
      const ImageDownloadResult.downloaded().message,
      'Imagen descargada.',
    );
    expect(const ImageDownloadResult.cancelled().message, isNull);
  });
}
