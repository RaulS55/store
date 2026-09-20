import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../product_image_cache.dart';
import 'hive_catalog_cache.dart';
import 'hive_product_image_store.dart';

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

Future<HiveAesCipher> loadHiveCipher({FlutterSecureStorage? storage}) async {
  final secure = storage ?? const FlutterSecureStorage();
  try {
    var encoded = await secure.read(key: hiveEncryptionKeyName);
    if (encoded == null || encoded.isEmpty) {
      encoded = base64UrlEncode(Hive.generateSecureKey());
      await secure.write(key: hiveEncryptionKeyName, value: encoded);
    }
    return HiveAesCipher(base64Url.decode(encoded));
  } catch (error, stack) {
    debugPrint('Hive cipher load failed: $error');
    debugPrint('$stack');
    final encoded = base64UrlEncode(Hive.generateSecureKey());
    try {
      await secure.write(key: hiveEncryptionKeyName, value: encoded);
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
  bool initFlutter = true,
  String nameSuffix = '',
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    return await _openEncryptedCatalogCache(
      storage: storage,
      cipher: cipher,
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
  bool initFlutter = true,
  String nameSuffix = '',
}) async {
  if (initFlutter && !_hiveFlutterReady) {
    await Hive.initFlutter();
    _hiveFlutterReady = true;
  }
  final resolved = cipher ?? await loadHiveCipher(storage: storage);
  return HiveCatalogCache.open(cipher: resolved, nameSuffix: nameSuffix);
}

Future<ProductImageCache> openProductImageCache({
  bool initFlutter = true,
  String nameSuffix = '',
  Duration timeout = const Duration(seconds: 4),
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
    return ProductImageCache(fetch: fetch);
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
  return ProductImageCache(store: store, fetch: fetch);
}
