import '../../models/lot.dart';
import '../incremental_access.dart';
import '../lot_access.dart';
import 'cached_catalog_access.dart';
import 'hive_catalog_cache.dart';

class CachedLotAccess implements LotAccess {
  CachedLotAccess({
    required IncrementalLotAccess remote,
    required HiveCatalogCache cache,
    void Function(String message)? log,
  }) : _remote = remote,
       _cached = CachedCatalogAccess<Lot>(
         cache: cache,
         collection: CatalogCollection.lots,
         fromMap: Lot.fromMap,
         toMap: (item) => item.toMap(),
         updatedAtOf: (item) => item.updatedAt,
         createdAtOf: (item) => item.createdAt,
         fetchChanged: remote.fetchChanged,
         watchChanged: remote.watchChanged,
         saveRemote: remote.saveLot,
         log: log,
       );

  final IncrementalLotAccess _remote;
  final CachedCatalogAccess<Lot> _cached;

  @override
  String nextLotId(String companyId) => _remote.nextLotId(companyId);

  @override
  Stream<List<Lot>> watchLots(String companyId) {
    return _cached.watch(companyId);
  }

  @override
  Future<void> saveLot(String companyId, Lot lot) {
    return _cached.save(companyId, lot);
  }
}
