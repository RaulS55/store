import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer.dart';
import 'firestore_sync_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';

class FirestoreCustomerAccess implements IncrementalCustomerAccess {
  FirestoreCustomerAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _customers(String companyId) {
    return _db.collection('companies').doc(companyId).collection('customers');
  }

  Query<Map<String, dynamic>> _activeCustomers(String companyId) {
    return _customers(companyId).where('deletedAt', isNull: true);
  }

  @override
  String nextCustomerId(String companyId) {
    return _customers(companyId).doc().id;
  }

  @override
  Stream<List<Customer>> watchCustomers(String companyId) {
    return watchFirestoreQuery(
      query: _activeCustomers(companyId),
      map: _mapSnapshot,
      label: 'Customers',
    );
  }

  @override
  Future<List<Customer>> fetchChanged(String companyId, DateTime? since) async {
    final snap = await catalogSyncQuery(
      collection: _customers(companyId),
      since: since,
    ).get();
    return _mapSnapshot(snap);
  }

  @override
  Stream<List<Customer>> watchChanged(String companyId, DateTime since) {
    return watchFirestoreQuery(
      query: catalogSyncQuery(collection: _customers(companyId), since: since),
      map: _mapSnapshot,
      label: 'Customers delta',
    );
  }

  @override
  Future<void> saveCustomer(String companyId, Customer customer) {
    return _customers(companyId).doc(customer.id).set(customer.toMap());
  }

  List<Customer> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final customers = mapFirestoreDocs(
      snap: snap,
      fromMap: Customer.fromMap,
      label: 'Customer',
    );
    customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return customers;
  }
}
