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
    expect(
      history.any((order) => order.id == activeId && order.isClosed),
      isTrue,
    );
    expect(history.any((order) => order.isActive), isFalse);
  });

  test('VAT is disabled by default and applies only to active orders', () {
    final store = AppStore();
    final order = store.orders.first;
    expect(store.ivaEnabled, isFalse);
    expect(order.iva, 0);
    expect(order.total, order.subtotal);
    expect(OrderShare.message(order), isNot(contains('IVA')));

    store.setIvaEnabled(true);
    store.setIvaPercent(10.5);
    expect(order.ivaEnabled, isTrue);
    expect(order.ivaPercent, 10.5);
    expect(order.iva, closeTo(order.subtotal * 0.105, 0.001));
    expect(order.total, closeTo(order.subtotal + order.iva, 0.001));
    expect(OrderShare.message(order), contains('IVA (10.5%)'));

    final closedId = order.id;
    expect(store.closeOrder(closedId), isTrue);
    store.setIvaPercent(21);
    store.setIvaEnabled(false);
    final closed = store.orderById(closedId)!;
    expect(closed.ivaEnabled, isTrue);
    expect(closed.ivaPercent, 10.5);

    final created = store.createOrder(store.customers.first);
    expect(created.ivaEnabled, isFalse);
    expect(created.ivaPercent, 21);
  });
}
