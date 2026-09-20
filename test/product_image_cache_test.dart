import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:store_app/data/product_image_cache.dart';
import 'package:store_app/widgets/product_image.dart';

import 'fakes/catalog_harness.dart';

Uint8List _bytes(int fill) => Uint8List.fromList([fill, fill, fill]);

Uint8List _jpeg() {
  final image = img.Image(width: 8, height: 8);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      image.setPixelRgb(x, y, 200, 40, 40);
    }
  }
  return img.encodeJpg(image);
}

void main() {
  test('put and peek return the same bytes without fetching', () async {
    var fetches = 0;
    final cache = ProductImageCache(
      fetch: (url) async {
        fetches += 1;
        return _bytes(9);
      },
    );

    await cache.put('https://example.com/a.jpg', _bytes(1));

    expect(cache.peek('https://example.com/a.jpg'), _bytes(1));
    expect(await cache.load('https://example.com/a.jpg'), _bytes(1));
    expect(fetches, 0);
  });

  test('load fetches once and reuses the result', () async {
    var fetches = 0;
    final cache = ProductImageCache(
      fetch: (url) async {
        fetches += 1;
        await Future<void>.delayed(Duration.zero);
        return _bytes(url.endsWith('a.jpg') ? 2 : 3);
      },
    );

    final first = cache.load('https://example.com/a.jpg');
    final second = cache.load('https://example.com/a.jpg');
    expect(await first, _bytes(2));
    expect(await second, _bytes(2));
    expect(fetches, 1);
    expect(await cache.load('https://example.com/a.jpg'), _bytes(2));
    expect(fetches, 1);
  });

  test('load keeps a persisted store across cache instances', () async {
    final store = MemoryProductImageStore();
    var fetches = 0;
    final first = ProductImageCache(
      store: store,
      fetch: (url) async {
        fetches += 1;
        return _bytes(4);
      },
    );
    expect(await first.load('https://example.com/b.jpg'), _bytes(4));

    final second = ProductImageCache(
      store: store,
      fetch: (url) async {
        fetches += 1;
        return _bytes(8);
      },
    );
    expect(second.peek('https://example.com/b.jpg'), _bytes(4));
    expect(await second.load('https://example.com/b.jpg'), _bytes(4));
    expect(fetches, 1);
  });

  test('evicts the oldest entry when the cache is full', () async {
    final cache = ProductImageCache(
      maxEntries: 2,
      fetch: (url) async => _bytes(1),
    );
    await cache.put('https://example.com/1.jpg', _bytes(1));
    await cache.put('https://example.com/2.jpg', _bytes(2));
    await cache.put('https://example.com/3.jpg', _bytes(3));

    expect(cache.peek('https://example.com/1.jpg'), isNull);
    expect(cache.peek('https://example.com/2.jpg'), _bytes(2));
    expect(cache.peek('https://example.com/3.jpg'), _bytes(3));
  });

  test('remove drops a cached image', () async {
    final cache = ProductImageCache();
    await cache.put('https://example.com/gone.jpg', _bytes(5));
    cache.remove('https://example.com/gone.jpg');
    expect(cache.peek('https://example.com/gone.jpg'), isNull);
  });

  test('prefetch only downloads missing cover images', () async {
    final fetched = <String>[];
    final cache = ProductImageCache(
      fetch: (url) async {
        fetched.add(url);
        return _bytes(7);
      },
    );
    await cache.put('https://example.com/cover.jpg', _bytes(6));
    final product = testProduct().copyWith(
      images: const [
        'https://example.com/cover.jpg',
        'https://example.com/gallery.jpg',
        'asset-image',
      ],
    );

    await cache.prefetchProductImages([product]);
    expect(fetched, isEmpty);

    await cache.prefetchProductImages([product], coversOnly: false);
    expect(fetched, ['https://example.com/gallery.jpg']);
  });

  test('web does not fetch remote bytes because of CORS', () async {
    var fetches = 0;
    final cache = ProductImageCache(
      allowRemoteFetch: false,
      fetch: (url) async {
        fetches += 1;
        return _bytes(1);
      },
    );

    expect(await cache.load('https://example.com/web.jpg'), isNull);
    expect(fetches, 0);
    await cache.prefetch(['https://example.com/web.jpg']);
    expect(fetches, 0);
  });

  testWidgets('ProductImage paints cached bytes without hitting the network', (
    tester,
  ) async {
    const url = 'https://example.com/cached.jpg';
    final jpeg = _jpeg();
    final cache = ProductImageCache(
      fetch: (url) async => throw StateError('should not fetch'),
    );
    await cache.put(url, jpeg);

    await tester.pumpWidget(
      Provider.value(
        value: cache,
        child: const MaterialApp(
          home: Scaffold(body: ProductImage(path: url)),
        ),
      ),
    );

    expect(find.byKey(ValueKey('cached:$url:${jpeg.length}')), findsOneWidget);
    expect(find.byKey(ValueKey('network:$url')), findsNothing);
  });

  testWidgets('without remote fetch ProductImage uses Image.network', (
    tester,
  ) async {
    const url = 'https://example.com/live.jpg';
    final cache = ProductImageCache(
      allowRemoteFetch: false,
      fetch: (url) async => throw StateError('should not fetch'),
    );

    await tester.pumpWidget(
      Provider.value(
        value: cache,
        child: const MaterialApp(
          home: Scaffold(body: ProductImage(path: url)),
        ),
      ),
    );

    expect(find.byKey(ValueKey('network:$url')), findsOneWidget);
  });
}
