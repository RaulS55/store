import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:store_app/data/local/cached_product_access.dart';
import 'package:store_app/data/local/hive_bootstrap.dart';
import 'package:store_app/data/local/hive_catalog_cache.dart';
import 'package:store_app/models/product.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_incremental_access.dart';

var _hiveReady = false;
var _boxSuffix = 0;

Future<HiveCatalogCache> _openCache() async {
  if (!_hiveReady) {
    final dir = await Directory.systemTemp.createTemp('hive_catalog_test_');
    Hive.init(dir.path);
    _hiveReady = true;
  }
  _boxSuffix += 1;
  return HiveCatalogCache.open(
    cipher: HiveAesCipher(Hive.generateSecureKey()),
    nameSuffix: '_t$_boxSuffix',
  );
}

Future<void> _pumpUntil(bool Function() done, {int maxTurns = 40}) async {
  for (var i = 0; i < maxTurns; i++) {
    if (done()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition not met');
}

void main() {
  const companyId = 'co-1';
  const otherCompany = 'co-2';
  final early = DateTime.utc(2026, 9, 11, 10);
  final late = DateTime.utc(2026, 9, 11, 12);

  late HiveCatalogCache cache;

  setUp(() async {
    cache = await _openCache();
  });

  tearDown(() async {
    await cache.close();
  });

  group('HiveCatalogCache', () {
    test('upserts and loads only active docs for the company', () async {
      final live = testProduct(id: 'p1', createdAt: early);
      final deleted = testProduct(id: 'p2', createdAt: early, deletedAt: late);
      final other = testProduct(id: 'p3', createdAt: late, name: 'Otro');

      await cache.upsertAll(companyId, CatalogCollection.products, [
        live.toMap(),
        deleted.toMap(),
      ]);
      await cache.upsertAll(otherCompany, CatalogCollection.products, [
        other.toMap(),
      ]);

      final loaded = await cache.loadActive(
        companyId,
        CatalogCollection.products,
      );
      expect(loaded, hasLength(1));
      expect(loaded.single['id'], 'p1');
    });

    test('tombstone removes a previously cached doc', () async {
      final product = testProduct(id: 'p1', createdAt: early, updatedAt: early);
      await cache.upsertAll(companyId, CatalogCollection.products, [
        product.toMap(),
      ]);

      final tombstone = testProduct(
        id: 'p1',
        createdAt: early,
        updatedAt: late,
        deletedAt: late,
      );
      await cache.upsertAll(companyId, CatalogCollection.products, [
        tombstone.toMap(),
      ]);

      final loaded = await cache.loadActive(
        companyId,
        CatalogCollection.products,
      );
      expect(loaded, isEmpty);
    });

    test('ignores an older remote update', () async {
      final newer = testProduct(
        id: 'p1',
        name: 'Nuevo',
        createdAt: early,
        updatedAt: late,
      );
      final older = testProduct(
        id: 'p1',
        name: 'Viejo',
        createdAt: early,
        updatedAt: early,
      );
      await cache.upsertAll(companyId, CatalogCollection.products, [
        newer.toMap(),
      ]);
      await cache.upsertAll(companyId, CatalogCollection.products, [
        older.toMap(),
      ]);

      final loaded = await cache.loadActive(
        companyId,
        CatalogCollection.products,
      );
      expect(Product.fromMap('p1', loaded.single).name, 'Nuevo');
    });

    test('stores lastSyncAt per company and collection', () async {
      expect(cache.lastSyncAt(companyId, CatalogCollection.products), isNull);
      await cache.setLastSyncAt(companyId, CatalogCollection.products, late);
      expect(cache.lastSyncAt(companyId, CatalogCollection.products), late);
      expect(cache.lastSyncAt(companyId, CatalogCollection.customers), isNull);
    });

    test('schema mismatch wipes the collection and cursor', () async {
      await cache.upsertAll(companyId, CatalogCollection.products, [
        testProduct(id: 'p1', createdAt: early).toMap(),
      ]);
      await cache.setLastSyncAt(companyId, CatalogCollection.products, late);

      final meta = Hive.box<dynamic>('$catalogMetaBox${'_t$_boxSuffix'}');
      await meta.put('$companyId|products|schema', 0);

      final loaded = await cache.loadActive(
        companyId,
        CatalogCollection.products,
      );
      expect(loaded, isEmpty);
      expect(cache.lastSyncAt(companyId, CatalogCollection.products), isNull);
    });

    test('lots collection stores and clears with the company', () async {
      await cache.upsertAll(companyId, CatalogCollection.lots, [
        testLot(id: 'l1', createdAt: early).toMap(),
      ]);
      final loaded = await cache.loadActive(companyId, CatalogCollection.lots);
      expect(loaded, hasLength(1));
      expect(loaded.single['id'], 'l1');

      await cache.clearCompany(companyId);
      expect(
        await cache.loadActive(companyId, CatalogCollection.lots),
        isEmpty,
      );
    });

    test('replaceActive drops docs missing from the remote snapshot', () async {
      final keep = testProduct(id: 'p1', createdAt: early);
      final gone = testProduct(id: 'p2', createdAt: early);
      await cache.upsertAll(companyId, CatalogCollection.products, [
        keep.toMap(),
        gone.toMap(),
      ]);

      await cache.replaceActive(companyId, CatalogCollection.products, [
        keep.copyWith(name: 'Vigente').toMap(),
      ]);

      final loaded = await cache.loadActive(
        companyId,
        CatalogCollection.products,
      );
      expect(loaded, hasLength(1));
      expect(loaded.single['id'], 'p1');
      expect(loaded.single['name'], 'Vigente');
    });

    test('open reuses boxes already open', () async {
      final again = await HiveCatalogCache.open(
        cipher: HiveAesCipher(Hive.generateSecureKey()),
        nameSuffix: '_t$_boxSuffix',
      );
      await again.upsertAll(companyId, CatalogCollection.lots, [
        testLot(id: 'l-retry', createdAt: early).toMap(),
      ]);
      final loaded = await cache.loadActive(companyId, CatalogCollection.lots);
      expect(loaded.single['id'], 'l-retry');
    });
  });

  group('CachedProductAccess', () {
    late FakeIncrementalProductAccess remote;
    late CachedProductAccess access;

    setUp(() {
      remote = FakeIncrementalProductAccess();
      access = CachedProductAccess(remote: remote, cache: cache);
    });

    test(
      'watch emits Hive first and then merges a full remote fetch',
      () async {
        final cached = testProduct(id: 'p1', name: 'Local', createdAt: early);
        final remoteProduct = testProduct(
          id: 'p2',
          name: 'Remoto',
          createdAt: late,
        );
        await cache.upsertAll(companyId, CatalogCollection.products, [
          cached.toMap(),
        ]);
        remote.products[companyId] = {remoteProduct.id: remoteProduct};

        final events = <List<Product>>[];
        final sub = access.watchProducts(companyId).listen(events.add);
        await _pumpUntil(() => events.length >= 2);
        addTearDown(sub.cancel);

        expect(events.first.map((item) => item.id), ['p1']);
        expect(events.last.map((item) => item.id), containsAll(['p1', 'p2']));
        expect(remote.fetchSinceCalls, [isNull]);
        expect(cache.lastSyncAt(companyId, CatalogCollection.products), late);
      },
    );

    test('later watches fetch only updates after lastSyncAt', () async {
      final first = testProduct(id: 'p1', createdAt: early, updatedAt: early);
      remote.products[companyId] = {first.id: first};

      final firstSub = access.watchProducts(companyId).listen((_) {});
      await _pumpUntil(
        () => cache.lastSyncAt(companyId, CatalogCollection.products) != null,
      );
      await firstSub.cancel();

      final updated = testProduct(
        id: 'p1',
        name: 'Actualizado',
        createdAt: early,
        updatedAt: late,
      );
      remote.products[companyId] = {updated.id: updated};

      final events = <List<Product>>[];
      final secondSub = access.watchProducts(companyId).listen(events.add);
      await _pumpUntil(() => remote.fetchSinceCalls.length >= 2);
      await _pumpUntil(
        () => events.any(
          (list) => list.any((item) => item.name == 'Actualizado'),
        ),
      );
      addTearDown(secondSub.cancel);

      expect(remote.fetchSinceCalls.last, early);
    });

    test('watch keeps Hive data when the remote fetch fails', () async {
      final cached = testProduct(id: 'p1', createdAt: early);
      await cache.upsertAll(companyId, CatalogCollection.products, [
        cached.toMap(),
      ]);
      remote.fetchError = Exception('offline');

      final events = <List<Product>>[];
      final sub = access.watchProducts(companyId).listen(events.add);
      await _pumpUntil(() => events.isNotEmpty);
      addTearDown(sub.cancel);

      expect(events.single.single.id, 'p1');
      expect(remote.watchSinceCalls, isEmpty);
    });

    test('save writes Hive and delegates to the remote', () async {
      final product = testProduct(id: 'p1', createdAt: late, updatedAt: late);
      await access.saveProduct(companyId, product);

      final local = await cache.loadActive(
        companyId,
        CatalogCollection.products,
      );
      expect(local.single['id'], 'p1');
      expect(remote.products[companyId]!['p1']!.id, 'p1');
      expect(cache.lastSyncAt(companyId, CatalogCollection.products), late);
    });

    test('public catalog skips Firestore when the snapshot is fresh', () async {
      final publicAccess = CachedProductAccess(
        remote: remote,
        cache: cache,
        publicSafe: true,
        publicStaleAfter: const Duration(minutes: 5),
      );
      final cached = testProduct(id: 'p1', createdAt: early);
      await cache.upsertAll(companyId, CatalogCollection.products, [
        cached.toMap(),
      ]);
      await cache.setLastPublicSyncAt(
        companyId,
        CatalogCollection.products,
        DateTime.now().toUtc(),
      );
      remote.products[companyId] = {
        'p2': testProduct(id: 'p2', name: 'Nuevo', createdAt: late),
      };

      final events = <List<Product>>[];
      final sub = publicAccess.watchProducts(companyId).listen(events.add);
      await _pumpUntil(() => events.isNotEmpty);
      addTearDown(sub.cancel);

      expect(events.single.single.id, 'p1');
      expect(remote.fetchSinceCalls, isEmpty);
      expect(remote.watchSinceCalls, isEmpty);
    });

    test('public catalog replaces local docs on a stale snapshot', () async {
      final publicAccess = CachedProductAccess(
        remote: remote,
        cache: cache,
        publicSafe: true,
        publicStaleAfter: const Duration(minutes: 5),
      );
      final stale = testProduct(id: 'p-old', createdAt: early);
      final live = testProduct(id: 'p-new', name: 'Nuevo', createdAt: late);
      await cache.upsertAll(companyId, CatalogCollection.products, [
        stale.toMap(),
      ]);
      await cache.setLastPublicSyncAt(
        companyId,
        CatalogCollection.products,
        DateTime.utc(2026, 9, 11),
      );
      remote.products[companyId] = {live.id: live};

      final events = <List<Product>>[];
      final sub = publicAccess.watchProducts(companyId).listen(events.add);
      await _pumpUntil(
        () => events.any((list) => list.any((item) => item.id == 'p-new')),
      );
      addTearDown(sub.cancel);

      expect(events.last.map((item) => item.id), ['p-new']);
      expect(remote.fetchSinceCalls, [isNull]);
      expect(remote.watchSinceCalls, isEmpty);
      expect(
        await cache.loadActive(companyId, CatalogCollection.products),
        hasLength(1),
      );
    });

    test('live delta tombstones a cached product', () async {
      final product = testProduct(id: 'p1', createdAt: early, updatedAt: early);
      remote.products[companyId] = {product.id: product};

      final events = <List<Product>>[];
      final sub = access.watchProducts(companyId).listen(events.add);
      await _pumpUntil(
        () => events.any((list) => list.any((item) => item.id == 'p1')),
      );

      final tombstone = testProduct(
        id: 'p1',
        createdAt: early,
        updatedAt: late,
        deletedAt: late,
      );
      remote.products[companyId] = {tombstone.id: tombstone};
      remote.emitWatch(companyId);
      await _pumpUntil(
        () => events.last.where((item) => item.id == 'p1').isEmpty,
      );
      addTearDown(sub.cancel);

      expect(
        await cache.loadActive(companyId, CatalogCollection.products),
        isEmpty,
      );
    });
  });
}
