import '../models/order.dart';

abstract class OrderAccess {
  String nextOrderId(String companyId);

  Stream<List<DraftOrder>> watchOrders(String companyId);

  /// Live updates for a single order. Emits null if it is missing or deleted.
  Stream<DraftOrder?> watchOrder(String companyId, String orderId);

  Future<void> saveOrder(String companyId, DraftOrder order);

  /// Merges [order.lines] into an open catalog order without replacing staff
  /// fields. Quantities of the same [OrderLine.lineKey] are added.
  ///
  /// Throws [CatalogOrderLockedException] if the order is missing or closed.
  Future<void> updateCatalogOrder(String companyId, DraftOrder order);
}
