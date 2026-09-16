import 'dart:async';

import 'package:store_app/data/order_access.dart';
import 'package:store_app/models/order.dart';

class FakeOrderAccess implements OrderAccess {
  final orders = <String, Map<String, DraftOrder>>{};
  final _controllers = <String, StreamController<List<DraftOrder>>>{};
  var _seq = 0;

  String _id() => 'o-fake-${++_seq}';

  StreamController<List<DraftOrder>> _controller(String companyId) {
    return _controllers.putIfAbsent(
      companyId,
      StreamController<List<DraftOrder>>.broadcast,
    );
  }

  List<DraftOrder> _list(String companyId) {
    final list = [
      for (final order in [...?orders[companyId]?.values])
        if (!order.isDeleted) order,
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  String nextOrderId(String companyId) => _id();

  @override
  Stream<List<DraftOrder>> watchOrders(String companyId) async* {
    yield _list(companyId);
    yield* _controller(companyId).stream;
  }

  @override
  Future<void> saveOrder(String companyId, DraftOrder order) async {
    orders.putIfAbsent(companyId, () => {})[order.id] = order;
    _controller(companyId).add(_list(companyId));
  }
}
