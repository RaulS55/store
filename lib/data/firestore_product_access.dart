import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import 'product_access.dart';

class FirestoreProductAccess implements ProductAccess {
  FirestoreProductAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _products(String companyId) {
    return _db.collection('companies').doc(companyId).collection('products');
  }

  @override
  String nextProductId(String companyId) {
    return _products(companyId).doc().id;
  }

  @override
  Stream<List<Product>> watchProducts(String companyId) {
    final collection = _products(companyId);
    late final StreamController<List<Product>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    var loadingFallback = false;

    Future<void> emitFromGet() async {
      if (loadingFallback) return;
      loadingFallback = true;
      try {
        final snap = await collection.get();
        if (!controller.isClosed) {
          controller.add(_mapSnapshot(snap));
        }
      } catch (error, stack) {
        debugPrint('Products get failed: $error');
        debugPrint('$stack');
        if (!controller.isClosed) {
          controller.addError(error, stack);
        }
      } finally {
        loadingFallback = false;
      }
    }

    controller = StreamController<List<Product>>(
      onListen: () {
        sub = collection.snapshots().listen(
          (snap) => controller.add(_mapSnapshot(snap)),
          onError: (Object error, StackTrace stack) {
            debugPrint('Products snapshots failed: $error');
            debugPrint('$stack');
            unawaited(emitFromGet());
          },
        );
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> saveProduct(String companyId, Product product) {
    return _products(companyId).doc(product.id).set(product.toMap());
  }

  List<Product> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final products = [
      for (final doc in snap.docs) Product.fromMap(doc.id, doc.data()),
    ];
    products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return products;
  }
}
