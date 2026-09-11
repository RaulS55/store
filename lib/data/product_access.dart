import '../models/product.dart';

abstract class ProductAccess {
  String nextProductId(String companyId);

  Stream<List<Product>> watchProducts(String companyId);

  Future<void> saveProduct(String companyId, Product product);
}
