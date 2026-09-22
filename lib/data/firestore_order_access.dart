import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import 'firestore_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';

class FirestoreOrderAccess implements IncrementalOrderAccess {
  FirestoreOrderAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _orders(String companyId) {
    return _db.collection('companies').doc(companyId).collection('orders');
  }

  @override
  String nextOrderId(String companyId) {
    return _orders(companyId).doc().id;
  }

  @override
  Stream<List<DraftOrder>> watchOrders(String companyId) {
    return watchFirestoreQuery(
      collection: _orders(companyId),
      filters: const [FirestoreFilter.isNull('deletedAt')],
      fromMap: DraftOrder.fromMap,
      label: 'Orders',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<List<DraftOrder>> fetchChanged(String companyId, DateTime? since) {
    return fetchFirestoreQuery(
      collection: _orders(companyId),
      filters: catalogSyncFilters(since),
      fromMap: DraftOrder.fromMap,
      label: 'Order',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Stream<List<DraftOrder>> watchChanged(String companyId, DateTime since) {
    return watchFirestoreQuery(
      collection: _orders(companyId),
      filters: catalogSyncFilters(since),
      fromMap: DraftOrder.fromMap,
      label: 'Orders delta',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<void> saveOrder(String companyId, DraftOrder order) {
    return _orders(companyId).doc(order.id).set(order.toMap());
  }
}
