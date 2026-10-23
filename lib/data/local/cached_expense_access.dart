import '../../models/expense.dart';
import '../expense_access.dart';
import '../incremental_access.dart';
import 'cached_catalog_access.dart';
import 'hive_catalog_cache.dart';

class CachedExpenseAccess implements ExpenseAccess {
  CachedExpenseAccess({
    required IncrementalExpenseAccess remote,
    required HiveCatalogCache cache,
    void Function(String message)? log,
  }) : _remote = remote,
       _cached = CachedCatalogAccess<Expense>(
         cache: cache,
         collection: CatalogCollection.expenses,
         fromMap: Expense.fromMap,
         toMap: (item) => item.toMap(),
         updatedAtOf: (item) => item.updatedAt,
         createdAtOf: (item) => item.createdAt,
         fetchChanged: remote.fetchChanged,
         watchChanged: remote.watchChanged,
         saveRemote: remote.saveExpense,
         log: log,
       );

  final IncrementalExpenseAccess _remote;
  final CachedCatalogAccess<Expense> _cached;

  @override
  String nextExpenseId(String companyId) => _remote.nextExpenseId(companyId);

  @override
  Stream<List<Expense>> watchExpenses(String companyId) {
    return _cached.watch(companyId);
  }

  @override
  Future<void> saveExpense(String companyId, Expense expense) {
    return _cached.save(companyId, expense);
  }
}
