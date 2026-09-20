import '../../models/customer.dart';
import '../customer_access.dart';
import '../incremental_access.dart';
import 'cached_catalog_access.dart';
import 'hive_catalog_cache.dart';

class CachedCustomerAccess implements CustomerAccess {
  CachedCustomerAccess({
    required IncrementalCustomerAccess remote,
    required HiveCatalogCache cache,
    void Function(String message)? log,
  }) : _remote = remote,
       _cached = CachedCatalogAccess<Customer>(
         cache: cache,
         collection: CatalogCollection.customers,
         fromMap: Customer.fromMap,
         toMap: (item) => item.toMap(),
         updatedAtOf: (item) => item.updatedAt,
         createdAtOf: (item) => item.createdAt,
         fetchChanged: remote.fetchChanged,
         watchChanged: remote.watchChanged,
         saveRemote: remote.saveCustomer,
         log: log,
       );

  final IncrementalCustomerAccess _remote;
  final CachedCatalogAccess<Customer> _cached;

  @override
  String nextCustomerId(String companyId) => _remote.nextCustomerId(companyId);

  @override
  Stream<List<Customer>> watchCustomers(String companyId) {
    return _cached.watch(companyId);
  }

  @override
  Future<void> saveCustomer(String companyId, Customer customer) {
    return _cached.save(companyId, customer);
  }
}
