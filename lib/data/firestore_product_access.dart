import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import 'firestore_watch.dart';
import 'product_access.dart';

class FirestoreProductAccess implements ProductAccess {
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
