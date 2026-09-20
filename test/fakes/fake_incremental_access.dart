import 'dart:async';

import 'package:store_app/data/incremental_access.dart';
import 'package:store_app/models/product.dart';

class FakeIncrementalProductAccess implements IncrementalProductAccess {
  final products = <String, Map<String, Product>>{};
  final fetchSinceCalls = <DateTime?>[];
  final watchSinceCalls = <DateTime>[];
  Object? fetchError;
  var _seq = 0;

  final _controllers = <String, StreamController<List<Product>>>{};

  StreamController<List<Product>> _controller(String companyId) {
    return _controllers.putIfAbsent(
      companyId,
      () => StreamController<List<Product>>.broadcast(),
    );
  }

  List<Product> changed(String companyId, DateTime? since) {
    final list = [...?products[companyId]?.values];
    if (since == null) {
      return [
        for (final product in list)
          if (!product.isDeleted) product,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return [
      for (final product in list)
        if (product.updatedAt.isAfter(since)) product,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void emitWatch(String companyId) {
    final since = watchSinceCalls.isEmpty
        ? DateTime.utc(1970)
        : watchSinceCalls.last;
    _controller(companyId).add(changed(companyId, since));
  }

  @override
  String nextProductId(String companyId) => 'p-inc-${++_seq}';

  @override
  Stream<List<Product>> watchProducts(String companyId) {
    throw UnsupportedError('use CachedProductAccess.watchProducts');
  }

  @override
  Future<List<Product>> fetchChanged(String companyId, DateTime? since) async {
    fetchSinceCalls.add(since);
    final error = fetchError;
    if (error != null) throw error;
    return changed(companyId, since);
  }

  @override
  Stream<List<Product>> watchChanged(String companyId, DateTime since) {
    watchSinceCalls.add(since);
    return _controller(companyId).stream;
  }

  @override
  Future<void> saveProduct(String companyId, Product product) async {
    products.putIfAbsent(companyId, () => {})[product.id] = product;
  }
}
