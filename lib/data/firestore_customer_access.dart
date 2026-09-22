import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer.dart';
import 'firestore_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';

class FirestoreCustomerAccess implements IncrementalCustomerAccess {
  FirestoreCustomerAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _customers(String companyId) {
    return _db.collection('companies').doc(companyId).collection('customers');
  }

  @override
  String nextCustomerId(String companyId) {
    return _customers(companyId).doc().id;
  }

  @override
  Stream<List<Customer>> watchCustomers(String companyId) {
    return watchFirestoreQuery(
      collection: _customers(companyId),
      filters: const [FirestoreFilter.isNull('deletedAt')],
      fromMap: Customer.fromMap,
      label: 'Customers',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<List<Customer>> fetchChanged(String companyId, DateTime? since) {
    return fetchFirestoreQuery(
      collection: _customers(companyId),
      filters: catalogSyncFilters(since),
      fromMap: Customer.fromMap,
      label: 'Customer',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Stream<List<Customer>> watchChanged(String companyId, DateTime since) {
    return watchFirestoreQuery(
      collection: _customers(companyId),
      filters: catalogSyncFilters(since),
      fromMap: Customer.fromMap,
      label: 'Customers delta',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<void> saveCustomer(String companyId, Customer customer) {
    return _customers(companyId).doc(customer.id).set(customer.toMap());
  }
}
