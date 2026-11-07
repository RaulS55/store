import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/share_code.dart';
import 'share_link_access.dart';

class FirestoreShareLinkAccess implements ShareLinkAccess {
  FirestoreShareLinkAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _links {
    return _db.collection('shareLinks');
  }

  @override
  Future<ProductShareLink?> find(String code) async {
    if (!isShareCode(code)) return null;
    final snap = await _links.doc(code).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return usableShareLink(ProductShareLink.fromMap(snap.id, data));
  }

  @override
  Future<bool> create(ProductShareLink link) async {
    if (usableShareLink(link) == null) return false;
    final ref = _links.doc(link.code);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) throw const _ShareLinkTaken();
        tx.set(ref, link.toMap());
      });
      return true;
    } on _ShareLinkTaken {
      return false;
    }
  }
}

class _ShareLinkTaken implements Exception {
  const _ShareLinkTaken();
}
