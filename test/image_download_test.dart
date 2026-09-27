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
}
