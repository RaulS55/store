import 'dart:async';

import 'package:flutter/foundation.dart';

import 'hive_catalog_cache.dart';

class CachedCatalogAccess<T> {
  CachedCatalogAccess({
    required HiveCatalogCache cache,
    required String collection,
    required T Function(String id, Map<String, dynamic> map) fromMap,
    required Map<String, dynamic> Function(T value) toMap,
    required DateTime Function(T value) updatedAtOf,
    required DateTime Function(T value) createdAtOf,
    required Future<List<T>> Function(String companyId, DateTime? since)
    fetchChanged,
    required Stream<List<T>> Function(String companyId, DateTime since)
    watchChanged,
    required Future<void> Function(String companyId, T value) saveRemote,
    void Function(String message)? log,
    this.publicSafe = false,
    this.publicStaleAfter = const Duration(minutes: 5),
  }) : _cache = cache,
       _collection = collection,
       _fromMap = fromMap,
       _toMap = toMap,
       _updatedAtOf = updatedAtOf,
       _createdAtOf = createdAtOf,
       _fetchChanged = fetchChanged,
       _watchChanged = watchChanged,
       _saveRemote = saveRemote,
       _log = log ?? debugPrint;

  final HiveCatalogCache _cache;
  final String _collection;
  final T Function(String id, Map<String, dynamic> map) _fromMap;
  final Map<String, dynamic> Function(T value) _toMap;
  final DateTime Function(T value) _updatedAtOf;
  final DateTime Function(T value) _createdAtOf;
  final Future<List<T>> Function(String companyId, DateTime? since)
  _fetchChanged;
  final Stream<List<T>> Function(String companyId, DateTime since)
  _watchChanged;
  final Future<void> Function(String companyId, T value) _saveRemote;
  final void Function(String message) _log;
  final bool publicSafe;
  final Duration publicStaleAfter;

  Stream<List<T>> watch(String companyId) {
    late final StreamController<List<T>> controller;
    StreamSubscription<List<T>>? remoteSub;

    Future<void> emitLocal() async {
      final maps = await _cache.loadActive(companyId, _collection);
      final items = <T>[];
      for (final map in maps) {
        try {
          final id = (map['id'] as String?)?.trim() ?? '';
          if (id.isEmpty) continue;
          items.add(_fromMap(id, map));
        } catch (error, stack) {
          _log('Catalog $_collection decode failed: $error');
          _log('$stack');
        }
      }
      items.sort((a, b) => _createdAtOf(b).compareTo(_createdAtOf(a)));
      if (!controller.isClosed) controller.add(items);
    }

    Future<void> merge(List<T> changed) async {
      if (changed.isEmpty) return;
      await _cache.upsertAll(companyId, _collection, [
        for (final item in changed) _toMap(item),
      ]);
      DateTime? maxUpdated;
      for (final item in changed) {
        final at = _updatedAtOf(item);
        if (maxUpdated == null || at.isAfter(maxUpdated)) maxUpdated = at;
      }
      if (maxUpdated != null) {
        final current = _cache.lastSyncAt(companyId, _collection);
        if (current == null || maxUpdated.isAfter(current)) {
          await _cache.setLastSyncAt(companyId, _collection, maxUpdated);
        }
      }
      await emitLocal();
    }

    Future<void> syncPublic() async {
      final last = _cache.lastPublicSyncAt(companyId, _collection);
      final now = DateTime.now().toUtc();
      if (last != null && now.difference(last) < publicStaleAfter) {
        return;
      }
      try {
        final changed = await _fetchChanged(companyId, null);
        await _cache.replaceActive(companyId, _collection, [
          for (final item in changed) _toMap(item),
        ]);
        await _cache.setLastPublicSyncAt(companyId, _collection, now);
        await emitLocal();
      } catch (error, stack) {
        _log('Catalog $_collection public sync failed: $error');
        _log('$stack');
      }
    }

    Future<void> start() async {
      await emitLocal();
      if (publicSafe) {
        await syncPublic();
        return;
      }
      final since = _cache.lastSyncAt(companyId, _collection);
      var fetchOk = false;
      try {
        final changed = await _fetchChanged(companyId, since);
        fetchOk = true;
        await merge(changed);
      } catch (error, stack) {
        _log('Catalog $_collection sync failed: $error');
        _log('$stack');
      }
      if (controller.isClosed) return;
      final cursor = _cache.lastSyncAt(companyId, _collection);
      if (cursor == null && !fetchOk) return;
      remoteSub = _watchChanged(companyId, cursor ?? DateTime.utc(1970)).listen(
        (delta) => unawaited(merge(delta)),
        onError: (Object error, StackTrace stack) {
          _log('Catalog $_collection watch failed: $error');
          _log('$stack');
        },
      );
    }

    controller = StreamController<List<T>>(
      onListen: () => unawaited(start()),
      onCancel: () => remoteSub?.cancel(),
    );
    return controller.stream;
  }

  Future<void> save(String companyId, T item) async {
    await _cache.upsertAll(companyId, _collection, [_toMap(item)]);
    final at = _updatedAtOf(item);
    final current = _cache.lastSyncAt(companyId, _collection);
    if (current == null || at.isAfter(current)) {
      await _cache.setLastSyncAt(companyId, _collection, at);
    }
    await _saveRemote(companyId, item);
  }
}
