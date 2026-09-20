import '../../models/product.dart';
import '../incremental_access.dart';
import '../product_access.dart';
import 'cached_catalog_access.dart';
import 'hive_catalog_cache.dart';

class CachedProductAccess implements ProductAccess {
  CachedProductAccess({
    required IncrementalProductAccess remote,
    required HiveCatalogCache cache,
    void Function(String message)? log,
    bool publicSafe = false,
    Duration publicStaleAfter = const Duration(minutes: 5),
  }) : _remote = remote,
       _cached = CachedCatalogAccess<Product>(
         cache: cache,
         collection: CatalogCollection.products,
         fromMap: Product.fromMap,
         toMap: (item) => item.toMap(),
         updatedAtOf: (item) => item.updatedAt,
         createdAtOf: (item) => item.createdAt,
         fetchChanged: remote.fetchChanged,
         watchChanged: remote.watchChanged,
         saveRemote: remote.saveProduct,
         log: log,
         publicSafe: publicSafe,
         publicStaleAfter: publicStaleAfter,
       );

  final IncrementalProductAccess _remote;
  final CachedCatalogAccess<Product> _cached;

  @override
  String nextProductId(String companyId) => _remote.nextProductId(companyId);

  @override
  Stream<List<Product>> watchProducts(String companyId) {
    return _cached.watch(companyId);
  }

  @override
  Future<void> saveProduct(String companyId, Product product) {
    return _cached.save(companyId, product);
  }
}
