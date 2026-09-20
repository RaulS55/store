import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import 'firestore_sync_query.dart';
import 'firestore_watch.dart';
import 'incremental_access.dart';

class FirestoreProductAccess implements IncrementalProductAccess {
  FirestoreProductAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _products(String companyId) {
    return _db.collection('companies').doc(companyId).collection('products');
  }

  Query<Map<String, dynamic>> _activeProducts(String companyId) {
    return _products(companyId).where('deletedAt', isNull: true);
  }

  @override
  String nextProductId(String companyId) {
    return _products(companyId).doc().id;
  }

  @override
  Stream<List<Product>> watchProducts(String companyId) {
    return watchFirestoreQuery(
      query: _activeProducts(companyId),
      map: _mapSnapshot,
      label: 'Products',
    );
  }

  @override
  Future<List<Product>> fetchChanged(String companyId, DateTime? since) async {
    final snap = await catalogSyncQuery(
      collection: _products(companyId),
      since: since,
    ).get();
    return _mapSnapshot(snap);
  }

  @override
  Stream<List<Product>> watchChanged(String companyId, DateTime since) {
    return watchFirestoreQuery(
      query: catalogSyncQuery(collection: _products(companyId), since: since),
      map: _mapSnapshot,
      label: 'Products delta',
    );
  }

  @override
  Future<void> saveProduct(String companyId, Product product) {
    return _products(companyId).doc(product.id).set(product.toMap());
  }

  List<Product> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final products = mapFirestoreDocs(
      snap: snap,
      fromMap: Product.fromMap,
      label: 'Product',
    );
    products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return products;
  }
}
