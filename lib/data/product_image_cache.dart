import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';

typedef ProductImageFetcher = Future<Uint8List> Function(String url);

abstract class ProductImageStore {
  Uint8List? read(String url);

  Future<void> write(String url, Uint8List bytes);

  Future<void> delete(String url);

  Iterable<String> get keys;

  int lastAccessMillis(String url);

  int storedBytes(String url);
}

class MemoryProductImageStore implements ProductImageStore {
  final _bytes = <String, Uint8List>{};
  final _access = <String, int>{};
  var _clock = 0;

  @override
  Uint8List? read(String url) => _bytes[url];

  @override
  Future<void> write(String url, Uint8List bytes) async {
    _bytes[url] = bytes;
    _access[url] = ++_clock;
  }

  @override
  Future<void> delete(String url) async {
    _bytes.remove(url);
    _access.remove(url);
  }

  @override
  Iterable<String> get keys => _bytes.keys;

  @override
  int lastAccessMillis(String url) => _access[url] ?? 0;

  @override
  int storedBytes(String url) => _bytes[url]?.lengthInBytes ?? 0;
}

bool isNetworkProductImageUrl(String path) {
  final uri = Uri.tryParse(path);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

List<String> productImageUrls(
  Iterable<Product> products, {
  bool coversOnly = false,
}) {
  final urls = <String>[];
  final seen = <String>{};
  for (final product in products) {
    final images = coversOnly ? product.images.take(1) : product.images;
    for (final image in images) {
      if (!isNetworkProductImageUrl(image) || !seen.add(image)) continue;
      urls.add(image);
    }
  }
  return urls;
}

Future<Uint8List> fetchProductImageBytes(String url) async {
  final response = await http
      .get(Uri.parse(url))
      .timeout(const Duration(seconds: 20));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('Image HTTP ${response.statusCode}');
  }
  if (response.bodyBytes.isEmpty) {
    throw StateError('Empty image');
  }
  return response.bodyBytes;
}

class ProductImageCache {
  ProductImageCache({
    ProductImageStore? store,
    ProductImageFetcher? fetch,
    bool? allowRemoteFetch,
    this.maxEntries = 120,
    this.maxBytes = 40 * 1024 * 1024,
    this.maxImageBytes = 2 * 1024 * 1024,
  }) : _store = store ?? MemoryProductImageStore(),
       _fetch = fetch ?? fetchProductImageBytes,
       allowRemoteFetch = allowRemoteFetch ?? !kIsWeb;

  final ProductImageStore _store;
  final ProductImageFetcher _fetch;
  final bool allowRemoteFetch;
  final int maxEntries;
  final int maxBytes;
  final int maxImageBytes;
  final _memory = <String, Uint8List>{};
  final _inflight = <String, Future<Uint8List?>>{};

  Uint8List? peek(String url) {
    if (url.isEmpty) return null;
    final memory = _memory[url];
    if (memory != null && memory.isNotEmpty) return memory;
    final stored = _store.read(url);
    if (stored == null || stored.isEmpty) return null;
    _memory[url] = stored;
    return stored;
  }

  Future<void> put(String url, Uint8List bytes) async {
    if (url.isEmpty || bytes.isEmpty) return;
    if (bytes.lengthInBytes > maxImageBytes) return;
    _memory[url] = bytes;
    await _store.write(url, bytes);
    await _evict();
  }

  void remove(String url) {
    if (url.isEmpty) return;
    _memory.remove(url);
    unawaited(_store.delete(url));
  }

  Future<Uint8List?> load(String url) async {
    final cached = peek(url);
    if (cached != null) return cached;
    if (!isNetworkProductImageUrl(url) || !allowRemoteFetch) return null;
    return _inflight.putIfAbsent(url, () async {
      try {
        final bytes = await _fetch(url);
        if (bytes.isEmpty || bytes.lengthInBytes > maxImageBytes) return null;
        await put(url, bytes);
        return peek(url) ?? bytes;
      } catch (error) {
        debugPrint('Product image cache fetch failed: $url $error');
        return null;
      } finally {
        _inflight.remove(url);
      }
    });
  }

  Future<void> prefetch(Iterable<String> urls) async {
    final pending = [
      for (final url in urls)
        if (peek(url) == null && isNetworkProductImageUrl(url)) url,
    ];
    const batch = 3;
    for (var i = 0; i < pending.length; i += batch) {
      await Future.wait([
        for (final url in pending.skip(i).take(batch)) load(url),
      ]);
    }
  }

  Future<void> prefetchProductImages(
    Iterable<Product> products, {
    bool coversOnly = true,
  }) {
    return prefetch(productImageUrls(products, coversOnly: coversOnly));
  }

  Future<void> _evict() async {
    while (_overLimit) {
      final oldest = _oldestKey();
      if (oldest == null) return;
      _memory.remove(oldest);
      await _store.delete(oldest);
    }
  }

  bool get _overLimit {
    if (_store.keys.length > maxEntries) return true;
    var total = 0;
    for (final url in _store.keys) {
      total += _store.storedBytes(url);
      if (total > maxBytes) return true;
    }
    return false;
  }

  String? _oldestKey() {
    String? oldest;
    var oldestAt = 1 << 62;
    for (final url in _store.keys) {
      final at = _store.lastAccessMillis(url);
      if (at <= oldestAt) {
        oldestAt = at;
        oldest = url;
      }
    }
    return oldest;
  }
}
