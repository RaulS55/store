import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_query.dart';

Stream<List<T>> watchFirestoreQuery<T>({
  required CollectionReference<Map<String, dynamic>> collection,
  List<FirestoreFilter> filters = const [],
  required T Function(String id, Map<String, dynamic> data) fromMap,
  required String label,
  int Function(T a, T b)? compare,
}) {
  late final StreamController<List<T>> controller;
  StreamSubscription<List<FirestoreDoc>>? sub;
  var retries = 0;
  var fallingBack = false;

  List<T> mapDocs(List<FirestoreDoc> docs) {
    final items = mapFirestoreDocs(docs: docs, fromMap: fromMap, label: label);
    if (compare != null) items.sort(compare);
    return items;
  }

  Future<void> emitFromGet() async {
    if (fallingBack) return;
    fallingBack = true;
    try {
      final docs = await getFirestoreDocs(
        collection: collection,
        filters: filters,
      );
      if (!controller.isClosed) controller.add(mapDocs(docs));
    } catch (error, stack) {
      debugPrint('$label get failed: $error');
      debugPrint('$stack');
      if (!controller.isClosed) controller.addError(error, stack);
    } finally {
      fallingBack = false;
    }
  }

  void listen() {
    sub?.cancel();
    sub = snapshotsFirestoreDocs(collection: collection, filters: filters)
        .listen(
          (docs) {
            retries = 0;
            try {
              if (!controller.isClosed) controller.add(mapDocs(docs));
            } catch (error, stack) {
              debugPrint('$label map failed: $error');
              debugPrint('$stack');
              if (!controller.isClosed) controller.addError(error, stack);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (isFirestorePermissionDenied(error) &&
                retries < 5 &&
                !controller.isClosed) {
              retries += 1;
              Future<void>.delayed(Duration(milliseconds: 300 * retries), () {
                if (!controller.isClosed) listen();
              });
              return;
            }
            debugPrint('$label snapshots failed: $error');
            debugPrint('$stack');
            unawaited(emitFromGet());
          },
        );
  }

  controller = StreamController<List<T>>(
    onListen: () {
      unawaited(emitFromGet());
      listen();
    },
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}

Future<List<T>> fetchFirestoreQuery<T>({
  required CollectionReference<Map<String, dynamic>> collection,
  List<FirestoreFilter> filters = const [],
  required T Function(String id, Map<String, dynamic> data) fromMap,
  required String label,
  int Function(T a, T b)? compare,
}) async {
  final docs = await getFirestoreDocs(collection: collection, filters: filters);
  final items = mapFirestoreDocs(docs: docs, fromMap: fromMap, label: label);
  if (compare != null) items.sort(compare);
  return items;
}
