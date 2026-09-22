import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/map_value.dart';
import 'firestore_query.dart';

/// Reads query results through the JS modular API.
///
/// `cloud_firestore_web` still converts `docChanges()` to
/// [DocumentChangePlatform], and Firebase JS 12.17's pipelines bundle
/// returns objects that fail that cast. `.docs` stays usable.

@JS('firebase_firestore.getFirestore')
external JSAny _getFirestore();

@JS('firebase_firestore.collection')
external JSAny _collection(JSAny db, JSString path);

@JS('firebase_firestore.collectionGroup')
external JSAny _collectionGroup(JSAny db, JSString id);

@JS('firebase_firestore.where')
external JSAny _where(JSString field, JSString op, JSAny? value);

@JS('firebase_firestore.limit')
external JSAny _limit(JSNumber count);

@JS('firebase_firestore.getDocs')
external JSPromise<JSAny?> _getDocs(JSAny query);

@JS('firebase_firestore.onSnapshot')
external JSFunction _onSnapshot(JSAny query, JSFunction next, JSFunction error);

extension type _JsQuerySnapshot(JSObject _) implements JSObject {
  external JSArray get docs;
}

extension type _JsQueryDoc(JSObject _) implements JSObject {
  external JSString get id;
  external JSAny? data();
  external _JsRef get ref;
}

extension type _JsRef(JSObject _) implements JSObject {
  external JSString get path;
}

JSAny? _jsValue(Object? value) {
  if (value == null) return null;
  if (value is String) return value.toJS;
  if (value is bool) return value.toJS;
  if (value is int) return value.toJS;
  if (value is double) return value.toJS;
  return value.toString().toJS;
}

JSAny _jsQuery({
  CollectionReference<Map<String, dynamic>>? collection,
  FirebaseFirestore? firestore,
  String? collectionGroup,
  List<FirestoreFilter> filters = const [],
  int? limit,
}) {
  if (collection == null &&
      (collectionGroup == null || collectionGroup.isEmpty)) {
    throw ArgumentError('collection or collectionGroup is required');
  }
  final db = _getFirestore();
  var query = collection != null
      ? _collection(db, collection.path.toJS)
      : _collectionGroup(db, collectionGroup!.toJS);
  final constraints = <JSAny>[
    for (final filter in filters)
      _where(filter.field.toJS, filter.op.toJS, _jsValue(filter.value)),
    if (limit != null) _limit(limit.toJS),
  ];
  if (constraints.isEmpty) return query;
  final module =
      globalContext.getProperty('firebase_firestore'.toJS) as JSObject;
  for (final constraint in constraints) {
    query = module.callMethod('query'.toJS, query, constraint) as JSAny;
  }
  return query;
}

List<FirestoreDoc> _docsOf(JSAny? snapshot) {
  if (snapshot == null) return const [];
  final snap = _JsQuerySnapshot(snapshot as JSObject);
  final docs = <FirestoreDoc>[];
  for (final raw in snap.docs.toDart) {
    if (raw == null) continue;
    try {
      docs.add(_docOf(_JsQueryDoc(raw as JSObject)));
    } catch (error, stack) {
      debugPrint('Firestore doc skipped: $error');
      debugPrint('$stack');
    }
  }
  return docs;
}

FirestoreDoc _docOf(_JsQueryDoc doc) {
  final data = doc.data();
  return FirestoreDoc(
    id: doc.id.toDart,
    data: data == null ? <String, dynamic>{} : coerceStringKeyMap(data),
    path: doc.ref.path.toDart,
  );
}

bool _canEmit(StreamController<List<FirestoreDoc>> controller) {
  if (controller.isClosed) return false;
  return PlatformDispatcher.instance.implicitView != null ||
      PlatformDispatcher.instance.views.isNotEmpty;
}

void _emitDocs(
  StreamController<List<FirestoreDoc>> controller,
  JSAny? snapshot,
) {
  if (!_canEmit(controller)) return;
  try {
    controller.add(_docsOf(snapshot));
  } catch (error, stack) {
    debugPrint('Firestore snapshot map failed: $error');
    debugPrint('$stack');
  }
}

Future<List<FirestoreDoc>> getFirestoreDocs({
  CollectionReference<Map<String, dynamic>>? collection,
  FirebaseFirestore? firestore,
  String? collectionGroup,
  List<FirestoreFilter> filters = const [],
  int? limit,
}) async {
  final snapshot = await _getDocs(
    _jsQuery(
      collection: collection,
      firestore: firestore,
      collectionGroup: collectionGroup,
      filters: filters,
      limit: limit,
    ),
  ).toDart;
  return _docsOf(snapshot);
}

Stream<List<FirestoreDoc>> snapshotsFirestoreDocs({
  CollectionReference<Map<String, dynamic>>? collection,
  FirebaseFirestore? firestore,
  String? collectionGroup,
  List<FirestoreFilter> filters = const [],
  int? limit,
}) {
  late final StreamController<List<FirestoreDoc>> controller;
  JSFunction? unsubscribe;
  controller = StreamController<List<FirestoreDoc>>.broadcast(
    onListen: () {
      final query = _jsQuery(
        collection: collection,
        firestore: firestore,
        collectionGroup: collectionGroup,
        filters: filters,
        limit: limit,
      );
      unsubscribe = _onSnapshot(
        query,
        ((JSAny snapshot) {
          _emitDocs(controller, snapshot);
        }).toJS,
        ((JSAny error) {
          if (!_canEmit(controller)) return;
          controller.addError(error);
        }).toJS,
      );
    },
    onCancel: () {
      unsubscribe?.callAsFunction();
      unsubscribe = null;
    },
  );
  return controller.stream;
}
