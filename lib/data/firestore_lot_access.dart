import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lot.dart';
import 'firestore_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';

class FirestoreLotAccess implements IncrementalLotAccess {
  FirestoreLotAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _lots(String companyId) {
    return _db.collection('companies').doc(companyId).collection('lots');
  }

  @override
  String nextLotId(String companyId) {
    return _lots(companyId).doc().id;
  }

  @override
  Stream<List<Lot>> watchLots(String companyId) {
    return watchFirestoreQuery(
      collection: _lots(companyId),
      filters: const [FirestoreFilter.isNull('deletedAt')],
      fromMap: Lot.fromMap,
      label: 'Lots',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<List<Lot>> fetchChanged(String companyId, DateTime? since) {
    return fetchFirestoreQuery(
      collection: _lots(companyId),
      filters: catalogSyncFilters(since),
      fromMap: Lot.fromMap,
      label: 'Lot',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Stream<List<Lot>> watchChanged(String companyId, DateTime since) {
    return watchFirestoreQuery(
      collection: _lots(companyId),
      filters: catalogSyncFilters(since),
      fromMap: Lot.fromMap,
      label: 'Lots delta',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<void> saveLot(String companyId, Lot lot) {
    return _lots(companyId).doc(lot.id).set(lot.toMap());
  }
}
