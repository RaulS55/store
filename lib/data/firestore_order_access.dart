import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import 'firestore_watch.dart';
import 'order_access.dart';

class FirestoreOrderAccess implements OrderAccess {
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
  Future<void> saveOrder(String companyId, DraftOrder order) {
    return _orders(companyId).doc(order.id).set(order.toMap());
  }

  List<DraftOrder> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final orders = [
      for (final doc in snap.docs) DraftOrder.fromMap(doc.id, doc.data()),
    ];
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }
}
