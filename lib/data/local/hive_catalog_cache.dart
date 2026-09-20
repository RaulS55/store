import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../../models/map_date.dart';
import '../../models/map_value.dart';
import 'hive_bootstrap.dart';

class CatalogCollection {
  static const products = 'products';
  static const customers = 'customers';
  static const orders = 'orders';
  static const lots = 'lots';
}

class HiveCatalogCache {
  HiveCatalogCache({
    required Box<dynamic> products,
    required Box<dynamic> customers,
    required Box<dynamic> orders,
    required Box<dynamic> lots,
    required Box<dynamic> meta,
  }) : _products = products,
       _customers = customers,
       _orders = orders,
       _lots = lots,
       _meta = meta;

  static const schemaVersion = 2;

  final Box<dynamic> _products;
  final Box<dynamic> _customers;
  final Box<dynamic> _orders;
  final Box<dynamic> _lots;
  final Box<dynamic> _meta;

  static var _memorySuffix = 0;

  static Future<HiveCatalogCache> open({
    required HiveCipher cipher,
    String nameSuffix = '',
  }) async {
    Future<Box<dynamic>> openBox(String name) async {
      final boxName = '$name$nameSuffix';
      if (Hive.isBoxOpen(boxName)) return Hive.box<dynamic>(boxName);
      try {
        return await Hive.openBox<dynamic>(boxName, encryptionCipher: cipher);
      } catch (error, stack) {
        debugPrint('Hive open $boxName failed: $error');
        debugPrint('$stack');
        try {
          await Hive.deleteBoxFromDisk(boxName);
        } catch (_) {}
        try {
          return await Hive.openBox<dynamic>(boxName, encryptionCipher: cipher);
        } catch (error2, stack2) {
          debugPrint('Hive reopen $boxName failed: $error2');
          debugPrint('$stack2');
          return _openMemoryBox(boxName, cipher);
        }
      }
    }

    return HiveCatalogCache(
      products: await openBox(catalogProductsBox),
      customers: await openBox(catalogCustomersBox),
      orders: await openBox(catalogOrdersBox),
      lots: await openBox(catalogLotsBox),
      meta: await openBox(catalogMetaBox),
    );
  }

  static Future<HiveCatalogCache> openInMemory() async {
    _memorySuffix += 1;
    final cipher = HiveAesCipher(Hive.generateSecureKey());
    final suffix = '__mem$_memorySuffix';
    return HiveCatalogCache(
      products: await _openMemoryBox('$catalogProductsBox$suffix', cipher),
      customers: await _openMemoryBox('$catalogCustomersBox$suffix', cipher),
      orders: await _openMemoryBox('$catalogOrdersBox$suffix', cipher),
      lots: await _openMemoryBox('$catalogLotsBox$suffix', cipher),
      meta: await _openMemoryBox('$catalogMetaBox$suffix', cipher),
    );
  }

  static Future<Box<dynamic>> _openMemoryBox(String name, HiveCipher cipher) {
    return Hive.openBox<dynamic>(
      name,
      bytes: Uint8List(0),
      encryptionCipher: cipher,
    );
  }

  Box<dynamic> _box(String collection) {
    switch (collection) {
      case CatalogCollection.products:
        return _products;
      case CatalogCollection.customers:
        return _customers;
      case CatalogCollection.orders:
        return _orders;
      case CatalogCollection.lots:
        return _lots;
      default:
        throw ArgumentError.value(collection, 'collection');
    }
  }

  String _docKey(String companyId, String id) => '$companyId|$id';

  String _syncKey(String companyId, String collection) {
    return '$companyId|$collection|lastSyncAt';
  }

  String _publicSyncKey(String companyId, String collection) {
    return '$companyId|$collection|publicSyncAt';
  }

  String _schemaKey(String companyId, String collection) {
    return '$companyId|$collection|schema';
  }

  Future<void> ensureSchema(String companyId, String collection) async {
    final key = _schemaKey(companyId, collection);
    if (_meta.get(key) == schemaVersion) return;
    await _deleteCompanyCollection(companyId, collection);
    await _meta.delete(_syncKey(companyId, collection));
    await _meta.delete(_publicSyncKey(companyId, collection));
    await _meta.put(key, schemaVersion);
  }

  Future<List<Map<String, dynamic>>> loadActive(
    String companyId,
    String collection,
  ) async {
    await ensureSchema(companyId, collection);
    final box = _box(collection);
    final prefix = '$companyId|';
    final result = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      if (key is! String || !key.startsWith(prefix)) continue;
      final map = decodeCatalogMap(box.get(key));
      if (map == null || isDeletedMap(map)) continue;
      result.add(map);
    }
    return result;
  }

  Future<void> upsertAll(
    String companyId,
    String collection,
    List<Map<String, dynamic>> docs,
  ) async {
    await ensureSchema(companyId, collection);
    final box = _box(collection);
    for (final raw in docs) {
      final map = coerceStringKeyMap(raw);
      final id = (map['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) continue;
      final key = _docKey(companyId, id);
      final existing = decodeCatalogMap(box.get(key));
      if (existing != null) {
        final existingUpdated = parseOptionalMapDate(existing['updatedAt']);
        final incomingUpdated = parseOptionalMapDate(map['updatedAt']);
        if (existingUpdated != null &&
            incomingUpdated != null &&
            incomingUpdated.isBefore(existingUpdated)) {
          continue;
        }
      }
      if (isDeletedMap(map)) {
        await box.delete(key);
      } else {
        await box.put(key, encodeCatalogMap(map));
      }
    }
  }

  Future<void> replaceActive(
    String companyId,
    String collection,
    List<Map<String, dynamic>> docs,
  ) async {
    await ensureSchema(companyId, collection);
    final box = _box(collection);
    final prefix = '$companyId|';
    final keep = <String>{};
    for (final raw in docs) {
      final map = coerceStringKeyMap(raw);
      final id = (map['id'] as String?)?.trim() ?? '';
      if (id.isEmpty || isDeletedMap(map)) continue;
      final key = _docKey(companyId, id);
      keep.add(key);
      await box.put(key, encodeCatalogMap(map));
    }
    final stale = [
      for (final key in box.keys)
        if (key is String && key.startsWith(prefix) && !keep.contains(key)) key,
    ];
    if (stale.isNotEmpty) await box.deleteAll(stale);
  }

  DateTime? lastSyncAt(String companyId, String collection) {
    return _readMetaDate(_syncKey(companyId, collection));
  }

  DateTime? lastPublicSyncAt(String companyId, String collection) {
    return _readMetaDate(_publicSyncKey(companyId, collection));
  }

  DateTime? _readMetaDate(String key) {
    final raw = _meta.get(key);
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.parse(raw).toUtc();
  }

  Future<void> setLastSyncAt(
    String companyId,
    String collection,
    DateTime value,
  ) {
    return _meta.put(
      _syncKey(companyId, collection),
      value.toUtc().toIso8601String(),
    );
  }

  Future<void> setLastPublicSyncAt(
    String companyId,
    String collection,
    DateTime value,
  ) {
    return _meta.put(
      _publicSyncKey(companyId, collection),
      value.toUtc().toIso8601String(),
    );
  }

  Future<void> clearCompany(String companyId) async {
    for (final collection in [
      CatalogCollection.products,
      CatalogCollection.customers,
      CatalogCollection.orders,
      CatalogCollection.lots,
    ]) {
      await _deleteCompanyCollection(companyId, collection);
      await _meta.delete(_syncKey(companyId, collection));
      await _meta.delete(_publicSyncKey(companyId, collection));
      await _meta.delete(_schemaKey(companyId, collection));
    }
  }

  Future<void> _deleteCompanyCollection(
    String companyId,
    String collection,
  ) async {
    final box = _box(collection);
    final prefix = '$companyId|';
    final keys = [
      for (final key in box.keys)
        if (key is String && key.startsWith(prefix)) key,
    ];
    if (keys.isNotEmpty) await box.deleteAll(keys);
  }

  Future<void> close() async {
    await _products.close();
    await _customers.close();
    await _orders.close();
    await _lots.close();
    await _meta.close();
  }
}

bool isDeletedMap(Map<String, dynamic> map) {
  return parseOptionalMapDate(map['deletedAt']) != null;
}
