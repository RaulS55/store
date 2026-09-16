import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import 'customer_access.dart';

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
    final query = _activeCustomers(companyId);
    late final StreamController<List<Customer>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    var loadingFallback = false;

    Future<void> emitFromGet() async {
      if (loadingFallback) return;
      loadingFallback = true;
      try {
        final snap = await query.get();
        if (!controller.isClosed) {
          controller.add(_mapSnapshot(snap));
        }
      } catch (error, stack) {
        debugPrint('Customers get failed: $error');
        debugPrint('$stack');
        if (!controller.isClosed) {
          controller.addError(error, stack);
        }
      } finally {
        loadingFallback = false;
      }
    }

    controller = StreamController<List<Customer>>(
      onListen: () {
        sub = query.snapshots().listen(
          (snap) => controller.add(_mapSnapshot(snap)),
          onError: (Object error, StackTrace stack) {
            debugPrint('Customers snapshots failed: $error');
            debugPrint('$stack');
            unawaited(emitFromGet());
          },
        );
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
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
