import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../product_image_cache.dart';
import 'hive_catalog_cache.dart';
import 'hive_product_image_store.dart';
import 'web_key_store.dart';

/// Secure-storage key for the 256-bit AES key used by Hive catalog boxes.
///
/// On iOS/macOS the key lives in the Keychain; on Android in the Keystore.
/// On web, flutter_secure_storage is weaker than a device keystore — values
/// in the Hive boxes are still AES-256 encrypted, but the wrapping key is
/// only as protected as the browser storage backend.
const hiveEncryptionKeyName = 'hive_catalog_encryption_key';

const catalogProductsBox = 'catalog_products';
const catalogCustomersBox = 'catalog_customers';
const catalogOrdersBox = 'catalog_orders';
const catalogLotsBox = 'catalog_lots';
const catalogMetaBox = 'catalog_sync_meta';
const catalogGuestCartsBox = 'catalog_guest_carts';

var _hiveFlutterReady = false;

abstract class HiveKeyStore {
  Future<String?> read();

  Future<void> write(String value);
}

class MemoryHiveKeyStore implements HiveKeyStore {
  MemoryHiveKeyStore([this.value]);

  String? value;
  Object? readError;

  @override
  Future<String?> read() async {
    final error = readError;
    if (error != null) throw error;
    return value;
  }

  @override
  Future<void> write(String next) async {
    value = next;
  }
}

class SecureHiveKeyStore implements HiveKeyStore {
  SecureHiveKeyStore(
    this.storage, {
    this.timeout = const Duration(milliseconds: 800),
  });

  final FlutterSecureStorage storage;
  final Duration timeout;

  @override
  Future<String?> read() {
    return storage.read(key: hiveEncryptionKeyName).timeout(timeout);
  }

  @override
  Future<void> write(String value) {
    return storage
        .write(key: hiveEncryptionKeyName, value: value)
        .timeout(timeout);
  }
}

class WebLocalHiveKeyStore implements HiveKeyStore {
  @override
  Future<String?> read() async => readWebEncryptionKey(hiveEncryptionKeyName);

  @override
  Future<void> write(String value) async {
    writeWebEncryptionKey(hiveEncryptionKeyName, value);
  }
}

class CompositeHiveKeyStore implements HiveKeyStore {
  CompositeHiveKeyStore(this.stores);

  final List<HiveKeyStore> stores;

  @override
  Future<String?> read() async {
    String? found;
    for (final store in stores) {
      try {
        final value = await store.read();
        if (value != null && value.isNotEmpty) {
          found = value;
          break;
        }
      } catch (error, stack) {
        debugPrint('Hive key read failed: $error');
        debugPrint('$stack');
      }
    }
    if (found != null) {
      for (final store in stores) {
        try {
          await store.write(found);
        } catch (_) {}
      }
    }
    return found;
  }

  @override
  Future<void> write(String value) async {
    for (final store in stores) {
      try {
        await store.write(value);
      } catch (error, stack) {
        debugPrint('Hive key write failed: $error');
        debugPrint('$stack');
      }
    }
  }
}

List<HiveKeyStore> defaultHiveKeyStores({FlutterSecureStorage? storage}) {
  return [
    WebLocalHiveKeyStore(),
    SecureHiveKeyStore(storage ?? const FlutterSecureStorage()),
  ];
}

Future<HiveAesCipher> loadHiveCipher({
  FlutterSecureStorage? storage,
  HiveKeyStore? keys,
}) async {
  final store =
      keys ?? CompositeHiveKeyStore(defaultHiveKeyStores(storage: storage));
  try {
    var encoded = await store.read();
    if (encoded == null || encoded.isEmpty) {
      encoded = base64UrlEncode(Hive.generateSecureKey());
      await store.write(encoded);
    }
    return HiveAesCipher(base64Url.decode(encoded));
  } catch (error, stack) {
    debugPrint('Hive cipher load failed: $error');
    debugPrint('$stack');
    final encoded = base64UrlEncode(Hive.generateSecureKey());
    try {
      await store.write(encoded);
    } catch (_) {}
    return HiveAesCipher(base64Url.decode(encoded));
  }
}

/// Opens the encrypted catalog boxes. Call after [WidgetsFlutterBinding].
///
/// On web, IndexedDB / secure storage can hang in in-app browsers. After
/// [timeout] we fall back to an in-memory box so public catalog still loads.
Future<HiveCatalogCache> openEncryptedCatalogCache({
  FlutterSecureStorage? storage,
  HiveCipher? cipher,
  HiveKeyStore? keys,
  bool initFlutter = true,
  String nameSuffix = '',
  Duration timeout = const Duration(seconds: 12),
}) async {
  try {
    return await _openEncryptedCatalogCache(
      storage: storage,
      cipher: cipher,
      keys: keys,
      initFlutter: initFlutter,
      nameSuffix: nameSuffix,
    ).timeout(timeout);
  } catch (error, stack) {
    debugPrint('Encrypted catalog cache failed: $error');
    debugPrint('$stack');
    return HiveCatalogCache.openInMemory();
  }
}

Future<HiveCatalogCache> _openEncryptedCatalogCache({
  FlutterSecureStorage? storage,
  HiveCipher? cipher,
  HiveKeyStore? keys,
  bool initFlutter = true,
  String nameSuffix = '',
}) async {
  if (initFlutter && !_hiveFlutterReady) {
    await Hive.initFlutter();
    _hiveFlutterReady = true;
  }
  final resolved = cipher ?? await loadHiveCipher(storage: storage, keys: keys);
  return HiveCatalogCache.open(cipher: resolved, nameSuffix: nameSuffix);
}

Future<ProductImageCache> openProductImageCache({
  bool initFlutter = true,
  String nameSuffix = '',
  Duration timeout = const Duration(seconds: 15),
  ProductImageFetcher? fetch,
}) async {
  try {
    return await _openProductImageCache(
      initFlutter: initFlutter,
      nameSuffix: nameSuffix,
      fetch: fetch,
    ).timeout(timeout);
  } catch (error, stack) {
    debugPrint('Product image cache failed: $error');
    debugPrint('$stack');
    return ProductImageCache(fetch: fetch, allowRemoteFetch: !kIsWeb);
  }
}

Future<ProductImageCache> _openProductImageCache({
  bool initFlutter = true,
  String nameSuffix = '',
  ProductImageFetcher? fetch,
}) async {
  if (initFlutter && !_hiveFlutterReady) {
    await Hive.initFlutter();
    _hiveFlutterReady = true;
  }
  final store = await HiveProductImageStore.open(nameSuffix: nameSuffix);
  return ProductImageCache(
    store: store,
    fetch: fetch,
    allowRemoteFetch: !kIsWeb,
  );
}
