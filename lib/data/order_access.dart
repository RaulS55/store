import '../models/order.dart';

abstract class OrderAccess {
  String nextOrderId(String companyId);

  Stream<List<DraftOrder>> watchOrders(String companyId);

  Future<void> saveOrder(String companyId, DraftOrder order);

  /// Updates lines on an open catalog order without replacing staff fields.
  ///
  /// Throws [CatalogOrderLockedException] if the order is missing or closed.
  Future<void> updateCatalogOrder(String companyId, DraftOrder order);
}
