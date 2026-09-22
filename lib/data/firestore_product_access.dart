import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import 'firestore_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';

class FirestoreProductAccess implements IncrementalProductAccess {
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
    return watchFirestoreQuery(
      collection: _products(companyId),
      filters: const [FirestoreFilter.isNull('deletedAt')],
      fromMap: Product.fromMap,
      label: 'Products',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<List<Product>> fetchChanged(String companyId, DateTime? since) {
    return fetchFirestoreQuery(
      collection: _products(companyId),
      filters: catalogSyncFilters(since),
      fromMap: Product.fromMap,
      label: 'Product',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Stream<List<Product>> watchChanged(String companyId, DateTime since) {
    return watchFirestoreQuery(
      collection: _products(companyId),
      filters: catalogSyncFilters(since),
      fromMap: Product.fromMap,
      label: 'Products delta',
      compare: (a, b) => b.createdAt.compareTo(a.createdAt),
    );
  }

  @override
  Future<void> saveProduct(String companyId, Product product) {
    return _products(companyId).doc(product.id).set(product.toMap());
  }
}
