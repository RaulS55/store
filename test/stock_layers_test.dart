import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/lot_stats.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/models/product.dart';

import 'fakes/catalog_harness.dart';

void main() {
  test('a garment without layers keeps its lot on the current stock', () {
    final product = Product.fromMap('p1', {
      'name': 'Remera',
      'sku': 'RM-1',
      'brand': 'Test',
      'price': 10000,
      'images': <String>[],
      'variants': [
        {'size': 'M', 'color': 'Negro', 'stock': 4},
      ],
      'lotId': 'l1',
      'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
    });

    expect(product.lotId, 'l1');
    expect(product.unitsInLot('l1'), 4);
    expect(product.variants.single.layers.single.quantity, 4);
    expect(product.toMap()['lotId'], 'l1');

    final again = Product.fromMap(product.id, product.toMap());
    expect(again.unitsInLot('l1'), 4);
    expect(again.variants.single.layers.single.lotId, 'l1');
  });

  test('restock adds a second lot and sales take the oldest first', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertLot(
      testLot(id: 'l1', name: 'Lote A', cost: 20000, quantity: 2),
    );
    await store.upsertLot(
      testLot(id: 'l2', name: 'Lote B', cost: 45000, quantity: 3),
    );
    await store.upsertProduct(
      testProduct(id: 'p1', lotId: 'l1', stock: 2, price: 15000),
    );

    expect(
      await store.restockProduct(
        productId: 'p1',
        lotId: 'l2',
        quantities: const {'M|Negro': 3},
      ),
      isTrue,
    );

    final restocked = store.productById('p1')!;
    expect(restocked.stock, 5);
    expect(restocked.unitsInLot('l1'), 2);
    expect(restocked.unitsInLot('l2'), 3);
    expect(restocked.lotId, 'l1');

    final order = await seedTestOrder(store, product: restocked);
    store.setLineQty(order.id, order.lines.single.lineKey, 4);
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);

    final reserved = store.productById('p1')!;
    expect(reserved.unitsInLot('l1'), 0);
    expect(reserved.unitsInLot('l2'), 1);
    expect(reserved.stock, 1);
    expect(
      order.stockReservations.single.allocations.map(
        (allocation) => (allocation.lotId, allocation.quantity),
      ),
      [('l1', 2), ('l2', 2)],
    );

    final reservedA = store.statsForLot(store.lotById('l1')!);
    final reservedB = store.statsForLot(store.lotById('l2')!);
    expect(reservedA.availableUnits, 0);
    expect(reservedA.reservedUnits, 2);
    expect(reservedA.reservedValue, 30000);
    expect(reservedB.availableUnits, 1);
    expect(reservedB.reservedUnits, 2);
    expect(reservedB.reservedValue, 30000);

    store.setLineQty(order.id, order.lines.single.lineKey, 1);
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);
    final returned = store.productById('p1')!;
    expect(returned.unitsInLot('l1'), 1);
    expect(returned.unitsInLot('l2'), 3);
    expect(order.stockReservations.single.allocations.single.lotId, 'l1');

    expect(store.resetOrderStock(order.id), isTrue);
    final restored = store.productById('p1')!;
    expect(restored.unitsInLot('l1'), 2);
    expect(restored.unitsInLot('l2'), 3);
    expect(restored.stock, 5);
  });

  test(
    'restocking the same lot merges while an exhausted lot starts over',
    () async {
      final store = AppStore();
      addTearDown(store.dispose);
      await store.upsertProduct(testProduct(id: 'p1', lotId: 'l1', stock: 2));

      expect(
        await store.restockProduct(
          productId: 'p1',
          lotId: 'l1',
          quantities: const {'M|Negro': 2},
        ),
        isTrue,
      );
      expect(store.productById('p1')!.variants.single.layers, hasLength(1));
      expect(store.productById('p1')!.unitsInLot('l1'), 4);

      expect(
        await store.restockProduct(
          productId: 'p1',
          lotId: 'l2',
          quantities: const {'M|Negro': 3},
        ),
        isTrue,
      );
      store.updateVariantStock('p1', 'M', 'Negro', stock: 3);
      expect(store.productById('p1')!.unitsInLot('l1'), 0);
      expect(store.productById('p1')!.unitsInLot('l2'), 3);

      expect(
        await store.restockProduct(
          productId: 'p1',
          lotId: 'l1',
          quantities: const {'M|Negro': 2},
        ),
        isTrue,
      );
      final layers = store.productById('p1')!.variants.single.layers;
      expect(layers.map((layer) => layer.lotId), ['l2', 'l1']);
      expect(layers.map((layer) => layer.quantity), [3, 2]);
    },
  );

  test('saving extra units does not move the units already on a lot', () {
    final created = DateTime.utc(2026, 3, 1);
    final current = testProduct(
      id: 'p1',
      lotId: 'l1',
      stock: 4,
      createdAt: created,
    );
    final increased = current.variants.single.copyWith(stock: 6);
    final assignment = Product.assignLots(
      previous: current,
      variants: [increased],
      addedLotId: 'l2',
      canAssignLot: true,
      isEditing: true,
      receivedAt: DateTime.utc(2026, 4, 1),
    );

    expect(assignment.needsLot, isFalse);
    expect(assignment.lotId, 'l1');
    expect(assignment.variants.single.stock, 6);
    final layers = assignment.variants.single.layers;
    expect(layers.map((layer) => (layer.lotId, layer.quantity)), [
      ('l1', 4),
      ('l2', 2),
    ]);
  });

  test('an edit without a lot adds the new units to the latest lot', () {
    final current = testProduct(lotId: 'l1', stock: 4);
    final assignment = Product.assignLots(
      previous: current,
      variants: [current.variants.single.copyWith(stock: 6)],
      addedLotId: null,
      canAssignLot: true,
      isEditing: true,
      receivedAt: DateTime.utc(2026, 4, 1),
    );
    expect(assignment.needsLot, isFalse);
    expect(assignment.variants.single.stock, 6);
    expect(
      assignment.variants.single.layers.map(
        (layer) => (layer.lotId, layer.quantity),
      ),
      [('l1', 6)],
    );
  });

  test('restock without a lot adds units to the latest lot', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct(id: 'p1', lotId: 'l1', stock: 2));

    expect(
      await store.restockProduct(
        productId: 'p1',
        quantities: const {'M|Negro': 3},
      ),
      isTrue,
    );

    final product = store.productById('p1')!;
    expect(product.stock, 5);
    expect(product.unitsInLot('l1'), 5);
    expect(product.lotId, 'l1');
  });

  test('restock without any lot still increases stock', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct(id: 'p1', stock: 2));

    expect(
      await store.restockProduct(
        productId: 'p1',
        quantities: const {'M|Negro': 1},
      ),
      isTrue,
    );

    expect(store.productById('p1')!.stock, 3);
  });

  test('lowering stock consumes the oldest lot', () {
    final created = DateTime.utc(2026, 3, 1);
    final current = testProduct(lotId: 'l1', stock: 2, createdAt: created);
    final withSecond = Product.assignLots(
      previous: current,
      variants: [current.variants.single.copyWith(stock: 5)],
      addedLotId: 'l2',
      canAssignLot: true,
      isEditing: true,
      receivedAt: DateTime.utc(2026, 4, 1),
    );
    final previous = current.copyWith(
      variants: withSecond.variants,
      lotId: withSecond.lotId,
    );
    final lowered = Product.assignLots(
      previous: previous,
      variants: [previous.variants.single.copyWith(stock: 2)],
      addedLotId: null,
      canAssignLot: true,
      isEditing: true,
      receivedAt: DateTime.utc(2026, 5, 1),
    );

    expect(lowered.needsLot, isFalse);
    expect(lowered.variants.single.layers.map((layer) => layer.lotId), ['l2']);
    expect(lowered.variants.single.stock, 2);
    expect(lowered.lotId, 'l2');
  });

  test('someone who cannot assign lots adds units to the latest lot', () {
    final current = testProduct(
      lotId: 'l1',
      stock: 2,
      createdAt: DateTime.utc(2026, 3, 1),
    );
    final withSecond = Product.assignLots(
      previous: current,
      variants: [current.variants.single.copyWith(stock: 5)],
      addedLotId: 'l2',
      canAssignLot: true,
      isEditing: true,
      receivedAt: DateTime.utc(2026, 4, 1),
    );
    final previous = current.copyWith(
      variants: withSecond.variants,
      lotId: withSecond.lotId,
    );
    final added = Product.assignLots(
      previous: previous,
      variants: [previous.variants.single.copyWith(stock: 6)],
      addedLotId: 'l9',
      canAssignLot: false,
      isEditing: true,
      receivedAt: DateTime.utc(2026, 5, 1),
    );

    expect(added.needsLot, isFalse);
    expect(
      added.variants.single.layers.map(
        (layer) => (layer.lotId, layer.quantity),
      ),
      [('l1', 2), ('l2', 4)],
    );
  });

  test('old sales stay on the lot saved in the order line', () {
    final live = testProduct(id: 'p1', lotId: 'l2', stock: 4, price: 15000);
    final soldAs = testProduct(id: 'p1', lotId: 'l1', stock: 1, price: 15000);
    final closed = DraftOrder(
      id: 'o1',
      orderNumber: 'o1',
      customer: testCustomer(),
      status: OrderStatus.cerrado,
      closedAt: DateTime.utc(2026, 9, 20),
      lines: [
        OrderLine(product: soldAs, variant: soldAs.variants.first, quantity: 1),
      ],
    );

    final first = computeLotStats(
      lot: testLot(id: 'l1', cost: 10000, quantity: 2, unitCost: 5000),
      products: [live],
      openOrders: const [],
      closedOrders: [closed],
    );
    final second = computeLotStats(
      lot: testLot(id: 'l2', cost: 20000, quantity: 4, unitCost: 5000),
      products: [live],
      openOrders: const [],
      closedOrders: [closed],
    );

    expect(first.soldUnits, 1);
    expect(first.soldValue, 15000);
    expect(first.availableUnits, 0);
    expect(second.soldUnits, 0);
    expect(second.availableUnits, 4);
  });
}
