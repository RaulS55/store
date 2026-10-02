import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import 'firestore_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';
import 'session_exception.dart';

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
  Stream<DraftOrder?> watchOrder(String companyId, String orderId) {
    return _orders(companyId).doc(orderId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final order = DraftOrder.fromMap(snap.id, data);
      if (order.isDeleted) return null;
      return order;
    });
  }

  @override
  Future<void> saveOrder(String companyId, DraftOrder order) {
    return _orders(companyId).doc(order.id).set(order.toMap());
  }

  @override
  Future<void> updateCatalogOrder(String companyId, DraftOrder order) async {
    final ref = _orders(companyId).doc(order.id);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (!snap.exists || data == null) {
          throw const CatalogOrderLockedException();
        }
        final existing = DraftOrder.fromMap(snap.id, data);
        if (!existing.isCatalog || !existing.isActive || existing.isDeleted) {
          throw const CatalogOrderLockedException();
        }
        final merged = OrderLine.mergeAdded(existing.lines, order.lines);
        if (merged.isEmpty) {
          throw const CatalogOrderLockedException();
        }
        tx.update(ref, {
          'lines': [for (final line in merged) line.toMap()],
          'customer': order.customer.toMap(),
          'updatedAt': order.updatedAt.toUtc().toIso8601String(),
        });
      });
    } on CatalogOrderLockedException {
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        throw const CatalogOrderLockedException();
      }
      rethrow;
    }
  }
}
