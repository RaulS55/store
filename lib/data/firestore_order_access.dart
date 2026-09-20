import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import 'firestore_sync_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';

class FirestoreOrderAccess implements IncrementalOrderAccess {
  FirestoreOrderAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _orders(String companyId) {
    return _db.collection('companies').doc(companyId).collection('orders');
  }

  Query<Map<String, dynamic>> _activeOrders(String companyId) {
    return _orders(companyId).where('deletedAt', isNull: true);
  }

  @override
  String nextOrderId(String companyId) {
    return _orders(companyId).doc().id;
  }

  @override
  Stream<List<DraftOrder>> watchOrders(String companyId) {
    return watchFirestoreQuery(
      query: _activeOrders(companyId),
      map: _mapSnapshot,
      label: 'Orders',
    );
  }

  @override
  Future<List<DraftOrder>> fetchChanged(
    String companyId,
    DateTime? since,
  ) async {
    final snap = await catalogSyncQuery(
      collection: _orders(companyId),
      since: since,
    ).get();
    return _mapSnapshot(snap);
  }

  @override
  Stream<List<DraftOrder>> watchChanged(String companyId, DateTime since) {
    return watchFirestoreQuery(
      query: catalogSyncQuery(collection: _orders(companyId), since: since),
      map: _mapSnapshot,
      label: 'Orders delta',
    );
  }

  @override
  Future<void> saveOrder(String companyId, DraftOrder order) {
    return _orders(companyId).doc(order.id).set(order.toMap());
  }

  List<DraftOrder> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final orders = mapFirestoreDocs(
      snap: snap,
      fromMap: DraftOrder.fromMap,
      label: 'Order',
    );
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }
}
