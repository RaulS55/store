import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/order_share.dart';

void main() {
  test('seeded employee orders have customers, totals and WhatsApp text', () {
    final store = AppStore();
    expect(store.orders, hasLength(3));
    expect(store.orders.map((o) => o.customer.name).toSet(), {
      'Mónica Fernández',
      'Boutique Abril',
      'Ana García',
    });
    for (final order in store.orders) {
      expect(order.lines, isNotEmpty);
      expect(order.total, greaterThan(0));
      expect(order.categorySummary, isNotEmpty);
      expect(order.customer.whatsappDigits, startsWith('54'));
      expect(OrderShare.message(order), contains(order.orderNumber));
      expect(OrderShare.whatsappUri(order), isNotNull);
    }

    final created = store.addCustomer(name: '  Juan Pérez  ');
    expect(created.name, 'Juan Pérez');
    expect(created.phone, isNull);
    expect(created.cuit, isNull);
    expect(created.taxCondition, isNull);
    expect(store.customers.first, created);
  });

  test('closed orders leave the active list and stay in customer history', () {
    final store = AppStore();
    final activeId = store.orders.first.id;
    final customerId = store.orders.first.customer.id;
    expect(store.closeOrder(activeId), isTrue);
    expect(store.orders.any((order) => order.id == activeId), isFalse);
    expect(store.closedOrders.any((order) => order.id == activeId), isTrue);

    final history = store.ordersForCustomer(customerId);
    expect(history.any((order) => order.id == activeId && order.isClosed), isTrue);
    expect(history.any((order) => order.isActive), isFalse);
  });
}
