import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer.dart';
import 'customer_access.dart';
import 'firestore_watch.dart';

class FirestoreCustomerAccess implements CustomerAccess {
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
  Future<void> saveCustomer(String companyId, Customer customer) {
    return _customers(companyId).doc(customer.id).set(customer.toMap());
  }

  List<Customer> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final customers = [
      for (final doc in snap.docs) Customer.fromMap(doc.id, doc.data()),
    ];
    customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return customers;
  }
}
