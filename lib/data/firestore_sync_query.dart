import 'package:cloud_firestore/cloud_firestore.dart';

Query<Map<String, dynamic>> catalogSyncQuery({
  required CollectionReference<Map<String, dynamic>> collection,
  required DateTime? since,
}) {
  if (since == null) {
    return collection.where('deletedAt', isNull: true);
  }
  return collection.where(
    'updatedAt',
    isGreaterThan: since.toUtc().toIso8601String(),
  );
}
