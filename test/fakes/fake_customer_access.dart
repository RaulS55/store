import 'dart:async';

import 'package:store_app/data/customer_access.dart';
import 'package:store_app/models/customer.dart';

class FakeCustomerAccess implements CustomerAccess {
  final customers = <String, Map<String, Customer>>{};
  final _controllers = <String, StreamController<List<Customer>>>{};
  var _seq = 0;

  String _id() => 'c-fake-${++_seq}';

  StreamController<List<Customer>> _controller(String companyId) {
    return _controllers.putIfAbsent(
      companyId,
      StreamController<List<Customer>>.broadcast,
    );
  }

  List<Customer> _list(String companyId) {
    final list = [
      for (final customer in [...?customers[companyId]?.values])
        if (!customer.isDeleted) customer,
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  String nextCustomerId(String companyId) => _id();

  @override
  Stream<List<Customer>> watchCustomers(String companyId) async* {
    yield _list(companyId);
    yield* _controller(companyId).stream;
  }

  @override
  Future<void> saveCustomer(String companyId, Customer customer) async {
    customers.putIfAbsent(companyId, () => {})[customer.id] = customer;
    _controller(companyId).add(_list(companyId));
  }
}
