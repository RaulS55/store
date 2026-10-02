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
    final store = AppStore(
      orderAccess: access,
      customers: FakeCustomerAccess(),
    );
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
    expect(saved.sena, 0);
    expect(saved.toMap()['sena'], 0);
  });

  test('closeOrder persists the deposit entered for the order', () async {
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

    expect(store.closeOrder(order.id, sena: 2500), isTrue);
    await _flush();
    final saved = access.orders['co1']![order.id]!;
    expect(saved.sena, 2500);
    expect(saved.hasSena, isTrue);
    expect(saved.remaining, 7500);
    expect(saved.toMap()['sena'], 2500);
  });

  test('setOrderSena persists a deposit on an open order', () async {
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

    expect(store.setOrderSena(order.id, 2500), isTrue);
    await _flush();
    expect(order.sena, 2500);
    expect(order.hasSena, isTrue);
    expect(order.remaining, 7500);
    final saved = access.orders['co1']![order.id]!;
    expect(saved.sena, 2500);
    expect(saved.status, OrderStatus.borrador);

    expect(store.closeOrder(order.id), isTrue);
    await _flush();
    expect(order.sena, 2500);
    expect(access.orders['co1']![order.id]!.sena, 2500);
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
    expect(
      other.orders.map((item) => item.orderNumber),
      containsAll(['PED-1', 'PED-2']),
    );
    final nextCustomer = await seedTestCustomer(
      other,
      customer: testCustomer(id: 'c-3', name: 'Luis Gómez'),
    );
    final next = other.createOrder(nextCustomer);
    expect(next.orderNumber, 'PED-3');
  });

  test('customer rename copies into persisted orders', () async {
    final access = FakeOrderAccess();
    final store = AppStore(
      orderAccess: access,
      customers: FakeCustomerAccess(),
    );
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

  test(
    'createOrder opens a new order after the previous one is closed',
    () async {
      final store = AppStore(products: FakeProductAccess());
      addTearDown(store.dispose);
      final order = await seedTestOrder(store);
      expect(store.closeOrder(order.id), isTrue);
      final next = store.createOrder(order.customer);
      expect(next.id, isNot(order.id));
      expect(next.isActive, isTrue);
      expect(store.orders, hasLength(1));
    },
  );

  test(
    'selectCustomer rejects a customer who already has an open order',
    () async {
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
    },
  );

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
    expect(
      store.addToOrder(product, product.variants.first, orderId: second.id),
      isTrue,
    );
    expect(store.lastAddedOrderId, second.id);
    expect(store.addTargetOrders.first.id, second.id);
    expect(store.addTargetOrders.map((item) => item.id), [second.id, first.id]);
    store.setActiveOrder(first.id);
    expect(store.addTargetOrders.first.id, second.id);
  });

  test(
    'deleteOrder soft-deletes an open order and frees the customer',
    () async {
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
      final product = store.productById('p-test')!;
      final stockBefore = product.variants.first.stock;
      store.setActiveOrder(order.id);

      expect(await store.deleteOrder(order.id), isTrue);
      await _flush();

      expect(store.orders, isEmpty);
      expect(store.closedOrders, isEmpty);
      expect(store.orderById(order.id), isNull);
      expect(store.openOrderForCustomer(order.customer.id), isNull);
      expect(store.activeOrderId, isNull);
      expect(store.lastAddedOrderId, isNull);
      expect(store.productById('p-test')!.variants.first.stock, stockBefore);
      final saved = access.orders['co1']![order.id]!;
      expect(saved.deletedAt, isNotNull);
      expect(saved.isDeleted, isTrue);
      expect(saved.status, OrderStatus.borrador);

      final next = store.createOrder(order.customer);
      expect(next.id, isNot(order.id));
      expect(next.isActive, isTrue);
      expect(store.orders, hasLength(1));
    },
  );

  test(
    'deleteOrder ignores closed orders and leaves stock unchanged',
    () async {
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
      final stockAfterClose = store.productById('p-test')!.variants.first.stock;

      expect(await store.deleteOrder(order.id), isFalse);
      await _flush();
      expect(store.closedOrders.any((item) => item.id == order.id), isTrue);
      expect(store.orderById(order.id)!.isDeleted, isFalse);
      expect(access.orders['co1']![order.id]!.deletedAt, isNull);
      expect(
        store.productById('p-test')!.variants.first.stock,
        stockAfterClose,
      );
    },
  );

  test(
    'saveOrderStock reserves stock and stays idle until the order changes',
    () async {
      final store = AppStore();
      addTearDown(store.dispose);
      final order = await seedTestOrder(store);
      final line = order.lines.first;
      expect(order.stockNeedsSave, isTrue);
      expect(store.productById('p-test')!.variants.first.stock, 10);

      expect(store.saveOrderStock(order.id), SaveStockResult.saved);
      expect(order.stockNeedsSave, isFalse);
      expect(store.productById('p-test')!.variants.first.stock, 9);
      expect(store.saveOrderStock(order.id), SaveStockResult.unchanged);
      expect(store.productById('p-test')!.variants.first.stock, 9);

      store.setLineQty(order.id, line.lineKey, 3);
      expect(order.stockNeedsSave, isTrue);
      expect(store.lineQuantityCap(order.id, order.lines.first), 10);
      expect(store.saveOrderStock(order.id), SaveStockResult.saved);
      expect(order.stockNeedsSave, isFalse);
      expect(store.productById('p-test')!.variants.first.stock, 7);

      store.setLineQty(order.id, line.lineKey, 1);
      expect(store.saveOrderStock(order.id), SaveStockResult.saved);
      expect(store.productById('p-test')!.variants.first.stock, 9);

      store.removeLine(order.id, line.lineKey);
      expect(order.stockNeedsSave, isTrue);
      expect(store.saveOrderStock(order.id), SaveStockResult.saved);
      expect(order.stockReservations, isEmpty);
      expect(store.productById('p-test')!.variants.first.stock, 10);
    },
  );

  test('closeOrder does not deduct stock that was already reserved', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);
    expect(store.closeOrder(order.id), isTrue);
    expect(store.productById('p-test')!.variants.first.stock, 9);
    expect(store.closedOrders.first.stockReservations, isNotEmpty);
  });

  test(
    'closeOrder still deducts stock when the reservation was not saved',
    () async {
      final store = AppStore();
      addTearDown(store.dispose);
      final order = await seedTestOrder(store);
      expect(store.closeOrder(order.id), isTrue);
      expect(store.productById('p-test')!.variants.first.stock, 9);
    },
  );

  test('saveOrderStock rejects a reservation without enough stock', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    store.updateVariantStock('p-test', 'M', 'Negro', stock: 0);
    expect(store.saveOrderStock(order.id), SaveStockResult.insufficient);
    expect(order.stockReservations, isEmpty);
    expect(order.stockNeedsSave, isTrue);
    expect(store.productById('p-test')!.variants.first.stock, 0);
    expect(store.closeOrder(order.id), isFalse);
    expect(order.isActive, isTrue);
  });

  test('resetOrderStock returns reserved units to available stock', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);
    expect(store.productById('p-test')!.variants.first.stock, 9);
    expect(order.stockReservations, isNotEmpty);

    expect(store.resetOrderStock(order.id), isTrue);
    expect(store.productById('p-test')!.variants.first.stock, 10);
    expect(order.stockReservations, isEmpty);
    expect(order.stockNeedsSave, isTrue);
    expect(store.resetOrderStock(order.id), isFalse);
  });

  test(
    'lineSellableStock drops to zero when another order reserves the last unit',
    () async {
      final store = AppStore();
      addTearDown(store.dispose);
      await store.upsertProduct(testProduct(stock: 1));
      final product = store.productById('p-test')!;
      final firstCustomer = await seedTestCustomer(store);
      final secondCustomer = await seedTestCustomer(
        store,
        customer: testCustomer(id: 'c-2', name: 'Carla Pérez'),
      );
      final first = store.createOrder(firstCustomer);
      expect(
        store.addToOrder(product, product.variants.first, orderId: first.id),
        isTrue,
      );
      final second = store.createOrder(secondCustomer);
      expect(
        store.addToOrder(product, product.variants.first, orderId: second.id),
        isTrue,
      );
      expect(store.lineSellableStock(second.id, second.lines.first), 1);

      expect(store.saveOrderStock(first.id), SaveStockResult.saved);
      expect(store.closeOrder(first.id), isTrue);
      expect(store.productById('p-test')!.variants.first.stock, 0);
      expect(store.lineSellableStock(second.id, second.lines.first), 0);
      expect(store.saveOrderStock(second.id), SaveStockResult.insufficient);
    },
  );

  test('deleteOrder returns stock reserved by the open order', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);
    expect(await store.deleteOrder(order.id), isTrue);
    expect(store.productById('p-test')!.variants.first.stock, 10);
  });

  test('reopenOrder keeps reserved stock and allows edits', () async {
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
    expect(store.closeOrder(order.id, sena: 2500), isTrue);
    await _flush();
    expect(order.sena, 2500);
    final stockAfterClose = store.productById('p-test')!.variants.first.stock;
    final holds = [...order.stockReservations];
    expect(holds, isNotEmpty);

    expect(store.reopenOrder(order.id), ReopenOrderResult.reopened);
    await _flush();
    expect(order.isActive, isTrue);
    expect(order.closedAt, isNull);
    expect(order.sena, 2500);
    expect(store.orders.any((item) => item.id == order.id), isTrue);
    expect(store.closedOrders.any((item) => item.id == order.id), isFalse);
    expect(store.activeOrderId, order.id);
    expect(order.stockReservations, holds);
    expect(order.stockNeedsSave, isFalse);
    expect(store.productById('p-test')!.variants.first.stock, stockAfterClose);
    final saved = access.orders['co1']![order.id]!;
    expect(saved.status, OrderStatus.borrador);
    expect(saved.closedAt, isNull);
    expect(saved.sena, 2500);

    store.setLineQty(order.id, order.lines.first.lineKey, 2);
    expect(order.stockNeedsSave, isTrue);
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);
    expect(
      store.productById('p-test')!.variants.first.stock,
      stockAfterClose - 1,
    );
  });

  test(
    'reopenOrder rejects a customer who already has an open order',
    () async {
      final store = AppStore();
      addTearDown(store.dispose);
      final order = await seedTestOrder(store);
      expect(store.closeOrder(order.id), isTrue);
      final next = store.createOrder(order.customer);
      expect(next.id, isNot(order.id));
      expect(store.reopenOrder(order.id), ReopenOrderResult.customerBusy);
      expect(order.isClosed, isTrue);
      expect(store.closedOrders.any((item) => item.id == order.id), isTrue);
      expect(store.productById('p-test')!.variants.first.stock, 9);
    },
  );

  test('reserved units stay available to the same order', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct(stock: 2));
    final product = store.productById('p-test')!;
    final customer = await seedTestCustomer(store);
    final order = store.createOrder(customer);
    expect(
      store.addToOrder(product, product.variants.first, quantity: 2),
      isTrue,
    );
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);
    expect(store.productById('p-test')!.variants.first.stock, 0);

    final lineKey = order.lines.first.lineKey;
    store.setLineQty(order.id, lineKey, 1);
    expect(order.stockNeedsSave, isTrue);
    store.setLineQty(order.id, lineKey, 2);
    expect(order.lines.first.quantity, 2);
    expect(order.stockNeedsSave, isFalse);
    expect(store.productById('p-test')!.variants.first.stock, 0);
  });

  test(
    'setLineUnitPrice persists an override and clears it at list price',
    () async {
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
      final lineKey = order.lines.first.lineKey;

      store.setLineUnitPrice(order.id, lineKey, 8000);
      await _flush();
      expect(order.lines.first.hasCustomPrice, isTrue);
      expect(order.lines.first.unitPrice, 8000);
      expect(order.subtotal, 8000);
      expect(
        access.orders['co1']![order.id]!.lines.first.unitPriceOverride,
        8000,
      );

      store.addToOrder(
        store.productById('p-test')!,
        store.productById('p-test')!.variants.first,
      );
      await _flush();
      expect(order.lines.first.quantity, 2);
      expect(order.lines.first.unitPriceOverride, 8000);
      expect(order.subtotal, 16000);

      store.setLineUnitPrice(order.id, lineKey, 10000);
      await _flush();
      expect(order.lines.first.hasCustomPrice, isFalse);
      expect(order.lines.first.unitPrice, 10000);
      expect(
        access.orders['co1']![order.id]!.lines.first.toMap().containsKey(
          'unitPriceOverride',
        ),
        isFalse,
      );
    },
  );

  test('setLineUnitPrice ignores closed orders', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    final lineKey = order.lines.first.lineKey;
    expect(store.closeOrder(order.id), isTrue);

    store.setLineUnitPrice(order.id, lineKey, 8000);
    expect(store.closedOrders.first.lines.first.hasCustomPrice, isFalse);
    expect(store.closedOrders.first.lines.first.unitPrice, 10000);
  });
}
