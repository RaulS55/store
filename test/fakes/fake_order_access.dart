import 'dart:async';

import 'package:store_app/data/order_access.dart';
import 'package:store_app/data/session_exception.dart';
import 'package:store_app/models/order.dart';

class FakeOrderAccess implements OrderAccess {
  final orders = <String, Map<String, DraftOrder>>{};
  final _controllers = <String, StreamController<List<DraftOrder>>>{};
  final _orderListeners = <String, Set<MultiStreamController<DraftOrder?>>>{};
  var _seq = 0;

  String _id() => 'o-fake-${++_seq}';

  String _orderKey(String companyId, String orderId) => '$companyId::$orderId';

  StreamController<List<DraftOrder>> _controller(String companyId) {
    return _controllers.putIfAbsent(
      companyId,
      StreamController<List<DraftOrder>>.broadcast,
    );
  }

  DraftOrder? _doc(String companyId, String orderId) {
    final order = orders[companyId]?[orderId];
    if (order == null || order.isDeleted) return null;
    return order;
  }

  List<DraftOrder> _list(String companyId) {
    final list = [
      for (final order in [...?orders[companyId]?.values])
        if (!order.isDeleted) order,
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void _emitOrder(String companyId, String orderId) {
    final order = _doc(companyId, orderId);
    for (final listener in [
      ...?_orderListeners[_orderKey(companyId, orderId)],
    ]) {
      listener.add(order);
    }
  }

  void emitOrder(String companyId, String orderId) {
    _emitOrder(companyId, orderId);
    _controller(companyId).add(_list(companyId));
  }

  @override
  String nextOrderId(String companyId) => _id();

  @override
  Stream<List<DraftOrder>> watchOrders(String companyId) async* {
    yield _list(companyId);
    yield* _controller(companyId).stream;
  }

  @override
  Stream<DraftOrder?> watchOrder(String companyId, String orderId) {
    final key = _orderKey(companyId, orderId);
    return Stream<DraftOrder?>.multi((listener) {
      _orderListeners.putIfAbsent(key, () => {}).add(listener);
      listener
        ..add(_doc(companyId, orderId))
        ..onCancel = () {
          _orderListeners[key]?.remove(listener);
        };
    }, isBroadcast: true);
  }

  @override
  Future<void> saveOrder(String companyId, DraftOrder order) async {
    orders.putIfAbsent(companyId, () => {})[order.id] = order;
    _controller(companyId).add(_list(companyId));
    _emitOrder(companyId, order.id);
  }

  @override
  Future<void> updateCatalogOrder(String companyId, DraftOrder order) async {
    final existing = orders[companyId]?[order.id];
    if (existing == null || !existing.isCatalog || !existing.isActive) {
      throw const CatalogOrderLockedException();
    }
    existing.customer = order.customer.copyWith(
      id: existing.customer.id,
      createdAt: existing.customer.createdAt,
      source: existing.customer.source,
    );
    final merged = OrderLine.mergeAdded(existing.lines, order.lines);
    existing.lines
      ..clear()
      ..addAll(merged);
    existing.updatedAt = order.updatedAt;
    emitOrder(companyId, order.id);
  }
}
