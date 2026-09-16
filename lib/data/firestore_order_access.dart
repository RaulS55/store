import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/order.dart';
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
    final query = _activeOrders(companyId);
    late final StreamController<List<DraftOrder>> controller;
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
        debugPrint('Orders get failed: $error');
        debugPrint('$stack');
        if (!controller.isClosed) {
          controller.addError(error, stack);
        }
      } finally {
        loadingFallback = false;
      }
    }

    controller = StreamController<List<DraftOrder>>(
      onListen: () {
        sub = query.snapshots().listen(
          (snap) => controller.add(_mapSnapshot(snap)),
          onError: (Object error, StackTrace stack) {
            debugPrint('Orders snapshots failed: $error');
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
