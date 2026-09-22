import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/map_value.dart';
import 'firestore_query.dart';

Query<Map<String, dynamic>> _query({
  CollectionReference<Map<String, dynamic>>? collection,
  FirebaseFirestore? firestore,
  String? collectionGroup,
  List<FirestoreFilter> filters = const [],
  int? limit,
}) {
  Query<Map<String, dynamic>> query;
  if (collection != null) {
    query = collection;
  } else {
    query = (firestore ?? FirebaseFirestore.instance).collectionGroup(
      collectionGroup!,
    );
  }
  for (final filter in filters) {
    if (filter.isNull) {
      query = query.where(filter.field, isNull: true);
    } else if (filter.op == '>') {
      query = query.where(filter.field, isGreaterThan: filter.value);
    } else {
      query = query.where(filter.field, isEqualTo: filter.value);
    }
  }
  if (limit != null) {
    query = query.limit(limit);
  }
  return query;
}

FirestoreDoc _docOf(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  return FirestoreDoc(
    id: doc.id,
    data: coerceStringKeyMap(doc.data()),
    path: doc.reference.path,
  );
}

Future<List<FirestoreDoc>> getFirestoreDocs({
  CollectionReference<Map<String, dynamic>>? collection,
  FirebaseFirestore? firestore,
  String? collectionGroup,
  List<FirestoreFilter> filters = const [],
  int? limit,
}) async {
  final snap = await _query(
    collection: collection,
    firestore: firestore,
    collectionGroup: collectionGroup,
    filters: filters,
    limit: limit,
  ).get();
  return [for (final doc in snap.docs) _docOf(doc)];
}

Stream<List<FirestoreDoc>> snapshotsFirestoreDocs({
  CollectionReference<Map<String, dynamic>>? collection,
  FirebaseFirestore? firestore,
  String? collectionGroup,
  List<FirestoreFilter> filters = const [],
  int? limit,
}) {
  return _query(
    collection: collection,
    firestore: firestore,
    collectionGroup: collectionGroup,
    filters: filters,
    limit: limit,
  ).snapshots().map((snap) => [for (final doc in snap.docs) _docOf(doc)]);
}
