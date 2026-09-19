import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Stream<List<T>> watchFirestoreQuery<T>({
  required Query<Map<String, dynamic>> query,
  required List<T> Function(QuerySnapshot<Map<String, dynamic>> snap) map,
  required String label,
}) {
  late final StreamController<List<T>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
  var retries = 0;
  var fallingBack = false;

  bool isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  Future<void> emitFromGet() async {
    if (fallingBack) return;
    fallingBack = true;
    try {
      final snap = await query.get();
      if (!controller.isClosed) controller.add(map(snap));
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
    sub = query.snapshots().listen(
      (snap) {
        retries = 0;
        if (!controller.isClosed) controller.add(map(snap));
      },
      onError: (Object error, StackTrace stack) {
        if (isPermissionDenied(error) && retries < 5 && !controller.isClosed) {
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
    onListen: listen,
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}
