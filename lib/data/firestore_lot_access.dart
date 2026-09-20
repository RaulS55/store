import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lot.dart';
import 'firestore_sync_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';

class FirestoreLotAccess implements IncrementalLotAccess {
  FirestoreLotAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _lots(String companyId) {
    return _db.collection('companies').doc(companyId).collection('lots');
  }

  Query<Map<String, dynamic>> _activeLots(String companyId) {
    return _lots(companyId).where('deletedAt', isNull: true);
  }

  @override
  String nextLotId(String companyId) {
    return _lots(companyId).doc().id;
  }

  @override
  Stream<List<Lot>> watchLots(String companyId) {
    return watchFirestoreQuery(
      query: _activeLots(companyId),
      map: _mapSnapshot,
      label: 'Lots',
    );
  }

  @override
  Future<List<Lot>> fetchChanged(String companyId, DateTime? since) async {
    final snap = await catalogSyncQuery(
      collection: _lots(companyId),
      since: since,
    ).get();
    return _mapSnapshot(snap);
  }

  @override
  Stream<List<Lot>> watchChanged(String companyId, DateTime since) {
    return watchFirestoreQuery(
      query: catalogSyncQuery(collection: _lots(companyId), since: since),
      map: _mapSnapshot,
      label: 'Lots delta',
    );
  }

  @override
  Future<void> saveLot(String companyId, Lot lot) {
    return _lots(companyId).doc(lot.id).set(lot.toMap());
  }

  List<Lot> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final lots = mapFirestoreDocs(
      snap: snap,
      fromMap: Lot.fromMap,
      label: 'Lot',
    );
    lots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return lots;
  }
}
