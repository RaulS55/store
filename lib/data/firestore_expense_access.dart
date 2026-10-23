import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense.dart';
import 'firestore_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';

class FirestoreExpenseAccess implements IncrementalExpenseAccess {
  FirestoreExpenseAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _expenses(String companyId) {
    return _db.collection('companies').doc(companyId).collection('expenses');
  }

  @override
  String nextExpenseId(String companyId) {
    return _expenses(companyId).doc().id;
  }

  @override
  Stream<List<Expense>> watchExpenses(String companyId) {
    return watchFirestoreQuery(
      collection: _expenses(companyId),
      filters: const [FirestoreFilter.isNull('deletedAt')],
      fromMap: Expense.fromMap,
      label: 'Expenses',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<List<Expense>> fetchChanged(String companyId, DateTime? since) {
    return fetchFirestoreQuery(
      collection: _expenses(companyId),
      filters: catalogSyncFilters(since),
      fromMap: Expense.fromMap,
      label: 'Expense',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Stream<List<Expense>> watchChanged(String companyId, DateTime since) {
    return watchFirestoreQuery(
      collection: _expenses(companyId),
      filters: catalogSyncFilters(since),
      fromMap: Expense.fromMap,
      label: 'Expenses delta',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<void> saveExpense(String companyId, Expense expense) {
    return _expenses(companyId).doc(expense.id).set(expense.toMap());
  }
}
