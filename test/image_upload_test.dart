import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/image_compress.dart';

import 'fakes/fake_image_access.dart';
import 'fakes/fake_product_access.dart';

Uint8List _png({int width = 240, int height = 240}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, (x * 13) & 255, (y * 17) & 255, (x + y) & 255);
    }
  }
  return img.encodePng(image);
}

void main() {
  test('a product keeps at most 3 images', () {
    expect(maxProductImages, 3);
  });

  test('compressProductImage encodes a JPEG and reports both sizes', () async {
    final original = _png();
    final compressed = await compressProductImage(original);
    expect(compressed.originalByteCount, original.lengthInBytes);
    expect(compressed.compressedByteCount, compressed.bytes.lengthInBytes);
    expect(compressed.bytes.lengthInBytes, greaterThan(0));
    expect(compressed.bytes[0], 0xFF);
    expect(compressed.bytes[1], 0xD8);
    expect(
      imageUploadSizeLog(
        originalByteCount: compressed.originalByteCount,
        compressedByteCount: compressed.compressedByteCount,
      ),
      'Image upload originalBytes=${compressed.originalByteCount} '
      'compressedBytes=${compressed.compressedByteCount}',
    );
  });

  test(
    'compressProductImage rejects empty, invalid and oversized files',
    () async {
      expect(
        () => compressProductImage(Uint8List(0)),
        throwsA(isA<ImageUploadException>()),
      );
      expect(
        () => compressProductImage(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<ImageUploadException>()),
      );
      expect(
        () => compressProductImage(Uint8List(maxOriginalImageBytes + 1)),
        throwsA(isA<ImageUploadException>()),
      );
    },
  );

  test('prepareProductImage compresses JPEG and logs both sizes', () async {
    final original = _png();
    final images = FakeImageAccess();
    final logs = <String>[];
    final store = AppStore(
      products: FakeProductAccess(),
      images: images,
      log: logs.add,
    );
    addTearDown(store.dispose);
    store.bindCompany('co1');

    final compressed = await store.prepareProductImage(original);

    expect(images.uploads, isEmpty);
    expect(compressed.originalByteCount, original.lengthInBytes);
    expect(compressed.bytes[0], 0xFF);
    expect(compressed.bytes[1], 0xD8);
    expect(logs, [
      'Image compress start originalBytes=${original.lengthInBytes}',
      'Image upload originalBytes=${original.lengthInBytes} '
          'compressedBytes=${compressed.compressedByteCount}',
    ]);
  });

  test('upload stores the given JPEG without compressing again', () async {
    final original = _png();
    final images = FakeImageAccess();
    final logs = <String>[];
    final store = AppStore(
      products: FakeProductAccess(),
      images: images,
      log: logs.add,
    );
    addTearDown(store.dispose);
    store.bindCompany('co1');

    final compressed = await store.prepareProductImage(original);
    logs.clear();

    final url = await store.uploadProductImage(
      productId: 'p1',
      bytes: compressed.bytes,
    );

    expect(images.uploads, hasLength(1));
    final upload = images.uploads.single;
    expect(url, upload.url);
    expect(upload.companyId, 'co1');
    expect(upload.productId, 'p1');
    expect(upload.fileName, endsWith('.jpg'));
    expect(upload.contentType, 'image/jpeg');
    expect(upload.bytes, compressed.bytes);
    expect(logs, isEmpty);
    expect(store.cachedProductImage(url), compressed.bytes);
  });

  test('company logo upload stores a JPEG in branding', () async {
    final original = _png();
    final images = FakeImageAccess();
    final store = AppStore(products: FakeProductAccess(), images: images);
    addTearDown(store.dispose);
    store.bindCompany('co1');

    final compressed = await store.prepareProductImage(original);
    final url = await store.uploadCompanyLogo(bytes: compressed.bytes);

    expect(images.uploads, hasLength(1));
    final upload = images.uploads.single;
    expect(url, upload.url);
    expect(upload.companyId, 'co1');
    expect(upload.productId, isEmpty);
    expect(upload.fileName, startsWith('logo-'));
    expect(upload.contentType, 'image/jpeg');
    expect(store.cachedProductImage(url), compressed.bytes);

    await store.deleteCompanyLogo();
    expect(images.uploads, isEmpty);
  });

  test('upload fails when the catalog has no company', () async {
    final store = AppStore(
      products: FakeProductAccess(),
      images: FakeImageAccess(),
    );
    addTearDown(store.dispose);
    expect(
      () => store.uploadProductImage(productId: 'p1', bytes: _png()),
      throwsA(isA<ImageUploadException>()),
    );
  });
}
