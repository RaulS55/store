import 'package:cloud_firestore/cloud_firestore.dart';

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
    return _products(companyId).snapshots().map((snap) {
      final products = [
        for (final doc in snap.docs) Product.fromMap(doc.id, doc.data()),
      ];
      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return products;
    });
  }

  @override
  Future<void> saveProduct(String companyId, Product product) {
    return _products(companyId).doc(product.id).set(product.toMap());
  }
}
