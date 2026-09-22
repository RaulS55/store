import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import '../product_image_cache.dart';

const productImagesBox = 'product_images';
const productImagesMetaBox = 'product_images_meta';

/// Hive string keys are limited to 255 characters. Firebase download URLs
/// with tokens often exceed that, so the raw URL cannot be the box key.
String productImageStoreKey(String url) {
  final bytes = utf8.encode(url);
  var hash = _fnvOffset;
  for (final byte in bytes) {
    hash ^= BigInt.from(byte);
    hash = (hash * _fnvPrime) & _fnvMask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

final _fnvOffset = BigInt.parse('cbf29ce484222325', radix: 16);
final _fnvPrime = BigInt.parse('100000001b3', radix: 16);
final _fnvMask = BigInt.parse('ffffffffffffffff', radix: 16);

class HiveProductImageStore implements ProductImageStore {
  HiveProductImageStore({
    required Box<dynamic> bytes,
    required Box<dynamic> meta,
  }) : _bytes = bytes,
       _meta = meta;

  final Box<dynamic> _bytes;
  final Box<dynamic> _meta;

  static Future<HiveProductImageStore> open({String nameSuffix = ''}) async {
    Future<Box<dynamic>> openBox(String name) async {
      final boxName = '$name$nameSuffix';
      if (Hive.isBoxOpen(boxName)) return Hive.box<dynamic>(boxName);
      return Hive.openBox<dynamic>(boxName);
    }

    return HiveProductImageStore(
      bytes: await openBox(productImagesBox),
      meta: await openBox(productImagesMetaBox),
    );
  }

  @override
  Uint8List? read(String url) {
    final raw = _bytes.get(_key(url)) ?? _bytes.get(url);
    if (raw is Uint8List && raw.isNotEmpty) return raw;
    if (raw is List<int> && raw.isNotEmpty) return Uint8List.fromList(raw);
    return null;
  }

  @override
  Future<void> write(String url, Uint8List bytes) async {
    final key = _key(url);
    await _bytes.put(key, bytes);
    if (key != url && _bytes.containsKey(url)) {
      await _bytes.delete(url);
      await _meta.delete(url);
    }
    await _touch(key, url);
  }

  @override
  Future<void> delete(String url) async {
    await _bytes.delete(_key(url));
    await _bytes.delete(url);
    await _meta.delete(_key(url));
    await _meta.delete(url);
  }

  @override
  Iterable<String> get keys => {
    for (final key in _bytes.keys)
      if (key is String) _urlFor(key),
  };

  @override
  int lastAccessMillis(String url) {
    final raw = _meta.get(_key(url)) ?? _meta.get(url);
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is Map) {
      final at = raw['at'];
      if (at is int) return at;
      if (at is num) return at.toInt();
    }
    return 0;
  }

  @override
  int storedBytes(String url) {
    final raw = _bytes.get(_key(url)) ?? _bytes.get(url);
    if (raw is Uint8List) return raw.lengthInBytes;
    if (raw is List<int>) return raw.length;
    return 0;
  }

  String _key(String url) => productImageStoreKey(url);

  String _urlFor(String key) {
    final raw = _meta.get(key);
    if (raw is Map && raw['url'] is String) return raw['url'] as String;
    return key;
  }

  Future<void> _touch(String key, String url) {
    return _meta.put(key, {
      'at': DateTime.now().toUtc().millisecondsSinceEpoch,
      'url': url,
    });
  }

  Future<void> close() async {
    await _bytes.close();
    await _meta.close();
  }
}
