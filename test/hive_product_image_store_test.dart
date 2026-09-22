import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:store_app/data/local/hive_product_image_store.dart';
import 'package:store_app/data/product_image_cache.dart';

var _hiveReady = false;
var _boxSuffix = 0;

Future<({HiveProductImageStore store, String suffix})> _openStore() async {
  if (!_hiveReady) {
    final dir = await Directory.systemTemp.createTemp('hive_images_test_');
    Hive.init(dir.path);
    _hiveReady = true;
  }
  _boxSuffix += 1;
  final suffix = '_t$_boxSuffix';
  return (
    store: await HiveProductImageStore.open(nameSuffix: suffix),
    suffix: suffix,
  );
}

Uint8List _bytes(int fill) => Uint8List.fromList([fill, fill, fill, fill]);

final longFirebaseUrl =
    'https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/'
    '${'companies%2Fco1%2Fproducts%2Fp1%2F' * 6}'
    'cover.jpg?alt=media&token=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

void main() {
  test('store keys stay short for long Firebase URLs', () {
    expect(longFirebaseUrl.length, greaterThan(255));
    final key = productImageStoreKey(longFirebaseUrl);
    expect(key.length, lessThan(32));
    expect(productImageStoreKey(longFirebaseUrl), key);
    expect(productImageStoreKey('$longFirebaseUrl&x=1'), isNot(key));
  });

  test('a long URL survives a new store instance', () async {
    final opened = await _openStore();
    addTearDown(opened.store.close);
    await opened.store.write(longFirebaseUrl, _bytes(9));
    expect(opened.store.read(longFirebaseUrl), _bytes(9));

    final second = await HiveProductImageStore.open(nameSuffix: opened.suffix);
    expect(second.read(longFirebaseUrl), _bytes(9));
    expect(second.keys, contains(longFirebaseUrl));
  });

  test(
    'cache load persists a long URL across ProductImageCache instances',
    () async {
      final opened = await _openStore();
      addTearDown(opened.store.close);
      var fetches = 0;
      final first = ProductImageCache(
        store: opened.store,
        fetch: (requested) async {
          fetches += 1;
          expect(requested, longFirebaseUrl);
          return _bytes(4);
        },
      );
      expect(await first.load(longFirebaseUrl), _bytes(4));

      final second = ProductImageCache(
        store: opened.store,
        fetch: (requested) async {
          fetches += 1;
          return _bytes(8);
        },
      );
      expect(second.peek(longFirebaseUrl), _bytes(4));
      expect(await second.load(longFirebaseUrl), _bytes(4));
      expect(fetches, 1);
    },
  );

  test('write migrates a legacy raw-url key', () async {
    final opened = await _openStore();
    addTearDown(opened.store.close);
    const url = 'https://example.com/legacy.jpg';
    final box = Hive.box<dynamic>('$productImagesBox${opened.suffix}');
    await box.put(url, _bytes(3));
    expect(opened.store.read(url), _bytes(3));

    await opened.store.write(url, _bytes(6));
    expect(opened.store.read(url), _bytes(6));
    expect(box.containsKey(url), isFalse);
    expect(box.containsKey(productImageStoreKey(url)), isTrue);
  });
}
