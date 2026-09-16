import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/order_share.dart';

import 'fakes/catalog_harness.dart';

void main() {
  test('catalog starts empty', () {
    final store = AppStore();
    expect(store.products, isEmpty);
    expect(store.orders, isEmpty);
    expect(store.closedOrders, isEmpty);
    expect(store.customers, isEmpty);
  });

  test('an order with a product has customer, total and WhatsApp text', () async {
    final store = AppStore();
    final order = await seedTestOrder(store);
    expect(order.customer.name, 'Mónica Fernández');
    expect(order.lines, isNotEmpty);
    expect(order.total, greaterThan(0));
    expect(order.categorySummary, isNotEmpty);
    expect(order.customer.whatsappDigits, startsWith('54'));
    expect(OrderShare.message(order), contains(order.orderNumber));
    expect(OrderShare.whatsappUri(order), isNotNull);

    final created = await store.addCustomer(name: '  Juan Pérez  ');
    expect(created.name, 'Juan Pérez');
    expect(created.phone, isNull);
    expect(created.cuit, isNull);
    expect(created.taxCondition, isNull);
    expect(store.customers.first, created);
  });

  test('closed orders leave the active list and stay in customer history', () async {
    final store = AppStore();
    final order = await seedTestOrder(store);
    final customerId = order.customer.id;
    expect(store.closeOrder(order.id), isTrue);
    expect(store.orders.any((item) => item.id == order.id), isFalse);
    expect(store.closedOrders.any((item) => item.id == order.id), isTrue);

    final history = store.ordersForCustomer(customerId);
    expect(
      history.any((item) => item.id == order.id && item.isClosed),
      isTrue,
    );
    expect(history.any((item) => item.isActive), isFalse);
  });

  test('VAT is disabled by default and applies only to active orders', () async {
    final store = AppStore();
    final order = await seedTestOrder(store);
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
