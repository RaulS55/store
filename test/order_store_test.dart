import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/order.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_customer_access.dart';
import 'fakes/fake_order_access.dart';
import 'fakes/fake_product_access.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('createOrder writes a document with sync fields', () async {
    final access = FakeOrderAccess();
    final store = AppStore(orderAccess: access, customers: FakeCustomerAccess());
    addTearDown(store.dispose);
    store.bindCompany('co1');
    await _flush();
    final customer = await seedTestCustomer(store);
    final order = store.createOrder(customer);
    await _flush();
    final saved = access.orders['co1']![order.id]!;
    expect(
      saved.toMap().keys,
      containsAll(['id', 'createdAt', 'updatedAt', 'deletedAt', 'status']),
    );
    expect(saved.id, order.id);
    expect(saved.orderNumber, 'PED-1');
    expect(saved.status, OrderStatus.borrador);
    expect(saved.deletedAt, isNull);
    expect(store.orderById(order.id), isNotNull);
    expect(store.orders, hasLength(1));
  });

  test('addToOrder persists lines on the same document', () async {
    final access = FakeOrderAccess();
    final store = AppStore(
      orderAccess: access,
      customers: FakeCustomerAccess(),
      products: FakeProductAccess(),
    );
    addTearDown(store.dispose);
    store.bindCompany('co1');
    await _flush();
    final order = await seedTestOrder(store);
    await _flush();
    final saved = access.orders['co1']![order.id]!;
    expect(saved.lines, isNotEmpty);
    expect(saved.itemCount, greaterThan(0));
    expect(store.orders.first.lines, isNotEmpty);
  });

  test('closeOrder leaves the open list and persists cerrado', () async {
    final access = FakeOrderAccess();
    final store = AppStore(
      orderAccess: access,
      customers: FakeCustomerAccess(),
      products: FakeProductAccess(),
    );
    addTearDown(store.dispose);
    store.bindCompany('co1');
    await _flush();
    final order = await seedTestOrder(store);
    await _flush();
    expect(store.closeOrder(order.id), isTrue);
    await _flush();
    expect(store.orders.any((item) => item.id == order.id), isFalse);
    expect(store.closedOrders.any((item) => item.id == order.id), isTrue);
    final saved = access.orders['co1']![order.id]!;
    expect(saved.status, OrderStatus.cerrado);
    expect(saved.closedAt, isNotNull);
    expect(saved.toMap()['status'], 'cerrado');
  });

  test('a second store sees open and closed orders from access', () async {
    final access = FakeOrderAccess();
    final customers = FakeCustomerAccess();
    final products = FakeProductAccess();
    final store = AppStore(
      orderAccess: access,
      customers: customers,
      products: products,
    );
    addTearDown(store.dispose);
    store.bindCompany('co1');
    await _flush();
    final order = await seedTestOrder(store);
    await _flush();
    expect(store.closeOrder(order.id), isTrue);
    await _flush();

    final other = AppStore(orderAccess: access);
    addTearDown(other.dispose);
    other.bindCompany('co1');
    await _flush();
    expect(other.orders, isEmpty);
    expect(other.closedOrders, hasLength(1));
    expect(other.closedOrders.first.id, order.id);
    expect(other.closedOrders.first.isClosed, isTrue);
    expect(other.orderById(order.id)!.customer.name, 'Mónica Fernández');
  });

  test('order numbers continue from persisted PED values', () async {
    final access = FakeOrderAccess();
    final customers = FakeCustomerAccess();
    final store = AppStore(orderAccess: access, customers: customers);
    addTearDown(store.dispose);
    store.bindCompany('co1');
    await _flush();
    final customer = await seedTestCustomer(store);
    store.createOrder(customer);
    store.createOrder(customer);
    await _flush();

    final other = AppStore(orderAccess: access, customers: customers);
    addTearDown(other.dispose);
    other.bindCompany('co1');
    await _flush();
    expect(other.orders.map((item) => item.orderNumber), containsAll(['PED-1', 'PED-2']));
    final next = other.createOrder(customer);
    expect(next.orderNumber, 'PED-3');
  });

  test('customer rename copies into persisted orders', () async {
    final access = FakeOrderAccess();
    final store = AppStore(orderAccess: access, customers: FakeCustomerAccess());
    addTearDown(store.dispose);
    store.bindCompany('co1');
    await _flush();
    final customer = await seedTestCustomer(store);
    final order = store.createOrder(customer);
    await _flush();
    await store.upsertCustomer(customer.copyWith(name: 'Boutique Abril'));
    await _flush();
    expect(store.orderById(order.id)!.customer.name, 'Boutique Abril');
    expect(access.orders['co1']![order.id]!.customer.name, 'Boutique Abril');
  });
}
