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
    var retries = 0;

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

    void listen() {
      sub?.cancel();
      sub = query.snapshots().listen(
        (snap) {
          retries = 0;
          controller.add(_mapSnapshot(snap));
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('Orders snapshots failed: $error');
          debugPrint('$stack');
          if (_isPermissionDenied(error) &&
              retries < 3 &&
              !controller.isClosed) {
            retries += 1;
            Future<void>.delayed(Duration(milliseconds: 400 * retries), () {
              if (!controller.isClosed) listen();
            });
            return;
          }
          unawaited(emitFromGet());
        },
      );
    }

    controller = StreamController<List<DraftOrder>>(
      onListen: listen,
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> saveOrder(String companyId, DraftOrder order) {
    return _orders(companyId).doc(order.id).set(order.toMap());
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  List<DraftOrder> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final orders = [
      for (final doc in snap.docs) DraftOrder.fromMap(doc.id, doc.data()),
    ];
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }
}
