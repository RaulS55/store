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
    final otherCustomer = await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-2', name: 'Ana López'),
    );
    store.createOrder(customer);
    store.createOrder(otherCustomer);
    await _flush();

    final other = AppStore(orderAccess: access, customers: customers);
    addTearDown(other.dispose);
    other.bindCompany('co1');
    await _flush();
    expect(other.orders.map((item) => item.orderNumber), containsAll(['PED-1', 'PED-2']));
    final nextCustomer = await seedTestCustomer(
      other,
      customer: testCustomer(id: 'c-3', name: 'Luis Gómez'),
    );
    final next = other.createOrder(nextCustomer);
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

  test('createOrder reuses the open order of the same customer', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final customer = await seedTestCustomer(store);
    final first = store.createOrder(customer);
    final second = store.createOrder(customer);
    expect(second.id, first.id);
    expect(store.orders, hasLength(1));
  });

  test('createOrder opens a new order after the previous one is closed', () async {
    final store = AppStore(products: FakeProductAccess());
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);
    final next = store.createOrder(order.customer);
    expect(next.id, isNot(order.id));
    expect(next.isActive, isTrue);
    expect(store.orders, hasLength(1));
  });

  test('selectCustomer rejects a customer who already has an open order', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final monica = await seedTestCustomer(store);
    final ana = await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-ana', name: 'Ana López'),
    );
    final monicaOrder = store.createOrder(monica);
    final anaOrder = store.createOrder(ana);
    expect(store.selectCustomer(anaOrder.id, monica), isFalse);
    expect(anaOrder.customer.id, ana.id);
    expect(store.openOrderForCustomer(monica.id)?.id, monicaOrder.id);
  });

  test('addToOrder remembers the last order a product was added to', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct());
    final product = store.productById('p-test')!;
    final monica = await seedTestCustomer(store);
    final ana = await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-ana', name: 'Ana López'),
    );
    final first = store.createOrder(monica);
    final second = store.createOrder(ana);
    store.setActiveOrder(first.id);
    expect(store.addToOrder(product, product.variants.first, orderId: second.id), isTrue);
    expect(store.lastAddedOrderId, second.id);
    expect(store.addTargetOrders.first.id, second.id);
    expect(store.addTargetOrders.map((item) => item.id), [second.id, first.id]);
    store.setActiveOrder(first.id);
    expect(store.addTargetOrders.first.id, second.id);
  });
}
