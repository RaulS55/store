import '../../models/order.dart';
import '../incremental_access.dart';
import '../order_access.dart';
import 'cached_catalog_access.dart';
import 'hive_catalog_cache.dart';

class CachedOrderAccess implements OrderAccess {
  CachedOrderAccess({
    required IncrementalOrderAccess remote,
    required HiveCatalogCache cache,
    void Function(String message)? log,
  }) : _remote = remote,
       _cached = CachedCatalogAccess<DraftOrder>(
         cache: cache,
         collection: CatalogCollection.orders,
         fromMap: DraftOrder.fromMap,
         toMap: (item) => item.toMap(),
         updatedAtOf: (item) => item.updatedAt,
         createdAtOf: (item) => item.createdAt,
         fetchChanged: remote.fetchChanged,
         watchChanged: remote.watchChanged,
         saveRemote: remote.saveOrder,
         log: log,
       );

  final IncrementalOrderAccess _remote;
  final CachedCatalogAccess<DraftOrder> _cached;

  @override
  String nextOrderId(String companyId) => _remote.nextOrderId(companyId);

  @override
  Stream<List<DraftOrder>> watchOrders(String companyId) {
    return _cached.watch(companyId);
  }

  @override
  Future<void> saveOrder(String companyId, DraftOrder order) {
    return _cached.save(companyId, order);
  }
}
