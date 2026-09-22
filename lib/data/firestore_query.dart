import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/map_value.dart';

export 'firestore_query_web.dart' if (dart.library.io) 'firestore_query_io.dart';

class FirestoreDoc {
  const FirestoreDoc({required this.id, required this.data, this.path = ''});

  final String id;
  final Map<String, dynamic> data;
  final String path;

  String? get parentDocumentId {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.length < 4) return null;
    return parts[parts.length - 3];
  }
}

class FirestoreFilter {
  const FirestoreFilter.equal(this.field, this.value) : op = '==';

  const FirestoreFilter.greaterThan(this.field, this.value) : op = '>';

  const FirestoreFilter.isNull(this.field) : op = '==', value = null;

  final String field;
  final String op;
  final Object? value;

  bool get isNull => value == null && op == '==';
}

List<FirestoreFilter> catalogSyncFilters(DateTime? since) {
  if (since == null) {
    return const [FirestoreFilter.isNull('deletedAt')];
  }
  return [
    FirestoreFilter.greaterThan('updatedAt', since.toUtc().toIso8601String()),
  ];
}

bool isFirestorePermissionDenied(Object error) {
  if (error is FirebaseException) {
    return error.code == 'permission-denied' ||
        error.code.endsWith('/permission-denied');
  }
  return '$error'.contains('permission-denied');
}

List<T> mapFirestoreDocs<T>({
  required List<FirestoreDoc> docs,
  required T Function(String id, Map<String, dynamic> data) fromMap,
  required String label,
}) {
  final items = <T>[];
  for (final doc in docs) {
    try {
      items.add(fromMap(doc.id, coerceStringKeyMap(doc.data)));
    } catch (error, stack) {
      debugPrint('$label ${doc.id} skipped: $error');
      debugPrint('$stack');
    }
  }
  return items;
}
