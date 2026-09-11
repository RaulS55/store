import 'dart:async';

import 'package:store_app/data/product_access.dart';
import 'package:store_app/models/product.dart';

class FakeProductAccess implements ProductAccess {
  final products = <String, Map<String, Product>>{};
  final _controllers = <String, StreamController<List<Product>>>{};
  var _seq = 0;

  String _id() => 'p-fake-${++_seq}';

  StreamController<List<Product>> _controller(String companyId) {
    return _controllers.putIfAbsent(
      companyId,
      StreamController<List<Product>>.broadcast,
    );
  }

  List<Product> _list(String companyId) {
    final list = [...?products[companyId]?.values];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  String nextProductId(String companyId) => _id();

  @override
  Stream<List<Product>> watchProducts(String companyId) async* {
    yield _list(companyId);
    yield* _controller(companyId).stream;
  }

  @override
  Future<void> saveProduct(String companyId, Product product) async {
    products.putIfAbsent(companyId, () => {})[product.id] = product;
    _controller(companyId).add(_list(companyId));
  }
}
