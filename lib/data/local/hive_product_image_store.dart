import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import '../product_image_cache.dart';

const productImagesBox = 'product_images';
const productImagesMetaBox = 'product_images_meta';

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
    final raw = _bytes.get(url);
    if (raw is Uint8List && raw.isNotEmpty) {
      _touch(url);
      return raw;
    }
    if (raw is List<int> && raw.isNotEmpty) {
      final bytes = Uint8List.fromList(raw);
      _touch(url);
      return bytes;
    }
    return null;
  }

  @override
  Future<void> write(String url, Uint8List bytes) async {
    await _bytes.put(url, bytes);
    await _touch(url);
  }

  @override
  Future<void> delete(String url) async {
    await _bytes.delete(url);
    await _meta.delete(url);
  }

  @override
  Iterable<String> get keys => [
    for (final key in _bytes.keys)
      if (key is String) key,
  ];

  @override
  int lastAccessMillis(String url) {
    final raw = _meta.get(url);
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  @override
  int storedBytes(String url) {
    final raw = _bytes.get(url);
    if (raw is Uint8List) return raw.lengthInBytes;
    if (raw is List<int>) return raw.length;
    return 0;
  }

  Future<void> _touch(String url) {
    return _meta.put(url, DateTime.now().toUtc().millisecondsSinceEpoch);
  }

  Future<void> close() async {
    await _bytes.close();
    await _meta.close();
  }
}
