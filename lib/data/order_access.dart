import '../models/order.dart';

abstract class OrderAccess {
  String nextOrderId(String companyId);

  Stream<List<DraftOrder>> watchOrders(String companyId);

  Future<void> saveOrder(String companyId, DraftOrder order);
}
