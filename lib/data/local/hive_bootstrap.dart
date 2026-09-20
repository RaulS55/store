import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'hive_catalog_cache.dart';

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
const catalogMetaBox = 'catalog_sync_meta';

Future<HiveAesCipher> loadHiveCipher({FlutterSecureStorage? storage}) async {
  final secure = storage ?? const FlutterSecureStorage();
  var encoded = await secure.read(key: hiveEncryptionKeyName);
  if (encoded == null || encoded.isEmpty) {
    encoded = base64UrlEncode(Hive.generateSecureKey());
    await secure.write(key: hiveEncryptionKeyName, value: encoded);
  }
  return HiveAesCipher(base64Url.decode(encoded));
}

/// Opens the encrypted catalog boxes. Call after [WidgetsFlutterBinding].
Future<HiveCatalogCache> openEncryptedCatalogCache({
  FlutterSecureStorage? storage,
  HiveCipher? cipher,
  bool initFlutter = true,
  String nameSuffix = '',
}) async {
  if (initFlutter) {
    await Hive.initFlutter();
  }
  final resolved = cipher ?? await loadHiveCipher(storage: storage);
  return HiveCatalogCache.open(cipher: resolved, nameSuffix: nameSuffix);
}
