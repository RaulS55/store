import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog_request.dart';
import 'catalog_request_access.dart';
import 'firestore_query.dart';
import 'firestore_watch.dart';

class FirestoreCatalogRequestAccess implements CatalogRequestAccess {
  FirestoreCatalogRequestAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _requests(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('catalogRequests');
  }

  @override
  String nextRequestId(String companyId) {
    return _requests(companyId).doc().id;
  }

  @override
  Stream<List<CatalogRequest>> watchRequests(String companyId) {
    return watchFirestoreQuery(
      collection: _requests(companyId),
      filters: const [FirestoreFilter.isNull('deletedAt')],
      fromMap: CatalogRequest.fromMap,
      label: 'Catalog requests',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Stream<CatalogRequest?> watchRequest(String companyId, String requestId) {
    return _requests(companyId).doc(requestId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final request = CatalogRequest.fromMap(snap.id, data);
      if (request.isDeleted) return null;
      return request;
    });
  }

  @override
  Future<CatalogRequest?> readRequest(
    String companyId,
    String requestId,
  ) async {
    final snap = await _requests(companyId).doc(requestId).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    final request = CatalogRequest.fromMap(snap.id, data);
    if (request.isDeleted) return null;
    return request;
  }

  @override
  Future<void> saveRequest(String companyId, CatalogRequest request) {
    return _requests(companyId).doc(request.id).set(request.toMap());
  }

  @override
  Future<void> updateRequest(
    String companyId,
    String requestId,
    Map<String, Object?> data,
  ) {
    return _requests(companyId).doc(requestId).update(data);
  }
}
