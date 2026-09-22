import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/lot_stats.dart';

import 'fakes/catalog_harness.dart';

void main() {
  test(
    'unsold lot with no garments still has the full investment to recover',
    () {
      final lot = testLot(cost: 40000, quantity: null, unitCost: null);
      final stats = computeLotStats(
        lot: lot,
        products: const [],
        openOrders: const [],
        closedOrders: const [],
      );
      expect(stats.garmentUnits, 0);
      expect(stats.availableUnits, 0);
      expect(stats.reservedUnits, 0);
      expect(stats.soldUnits, 0);
      expect(stats.unitPrice, isNull);
      expect(stats.soldValue, 0);
      expect(stats.reservedValue, 0);
      expect(stats.expectedValue, 0);
      expect(stats.recoveryRemainingPercent, 100);
      expect(stats.currentProfit, 0);
      expect(stats.expectedProfit, 0);
    },
  );

  test('assigned garments add their retail value and unit price', () {
    final lot = testLot(id: 'l1', cost: 40000, quantity: 10, unitCost: 4000);
    final stats = computeLotStats(
      lot: lot,
      products: [testProduct(lotId: 'l1', stock: 8, price: 15000)],
      openOrders: const [],
      closedOrders: const [],
    );
    expect(stats.garmentUnits, 8);
    expect(stats.availableUnits, 8);
    expect(stats.unitPrice, 4000);
    expect(stats.expectedValue, 120000);
    expect(stats.soldValue, 0);
    expect(stats.recoveryRemainingPercent, 100);
    expect(stats.currentProfit, 0);
    expect(stats.expectedProfit, 80000);
  });

  test(
    'closed orders count sold garments and reduce remaining recovery',
    () async {
      final store = AppStore();
      addTearDown(store.dispose);
      final lot = testLot(id: 'l1', cost: 40000, quantity: 10, unitCost: 4000);
      await store.upsertLot(lot);
      final product = testProduct(
        id: 'p1',
        lotId: 'l1',
        stock: 8,
        price: 15000,
      );
      await store.upsertProduct(product);
      final order = await seedTestOrder(store, product: product);
      expect(store.closeOrder(order.id), isTrue);

      final stats = store.statsForLot(lot);
      expect(stats.soldUnits, 1);
      expect(stats.availableUnits, 7);
      expect(stats.reservedUnits, 0);
      expect(stats.garmentUnits, 8);
      expect(stats.soldValue, 15000);
      expect(stats.expectedValue, 120000);
      expect(stats.recoveryRemainingPercent, 62.5);
      expect(stats.currentProfit, 0);
      expect(stats.expectedProfit, 80000);
    },
  );

  test('reserved stock counts its price without counting as sold', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final lot = testLot(id: 'l1', cost: 40000, quantity: 10, unitCost: 4000);
    await store.upsertLot(lot);
    final product = testProduct(id: 'p1', lotId: 'l1', stock: 8, price: 15000);
    await store.upsertProduct(product);
    final order = await seedTestOrder(store, product: product);
    store.setLineQty(order.id, order.lines.first.lineKey, 2);
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);

    final stats = store.statsForLot(store.lotById('l1')!);
    expect(stats.availableUnits, 6);
    expect(stats.reservedUnits, 2);
    expect(stats.soldUnits, 0);
    expect(stats.garmentUnits, 8);
    expect(stats.reservedValue, 30000);
    expect(stats.soldValue, 0);
    expect(stats.expectedValue, 120000);
    expect(stats.recoveryRemainingPercent, 100);
    expect(stats.currentProfit, 0);
    expect(stats.expectedProfit, 80000);
  });

  test('other-channel sales recover the investment and stay capped at 100', () {
    final lot = testLot(
      cost: 40000,
      quantity: null,
      unitCost: null,
      soldElsewhere: 50000,
    );
    final stats = computeLotStats(
      lot: lot,
      products: const [],
      openOrders: const [],
      closedOrders: const [],
    );
    expect(stats.soldValue, 50000);
    expect(stats.garmentValue, 0);
    expect(stats.expectedValue, 50000);
    expect(stats.recoveryRemainingPercent, 0);
    expect(stats.currentProfit, 10000);
    expect(stats.expectedProfit, 10000);
  });

  test('partial other-channel sales leave the remaining percent', () {
    final lot = testLot(
      cost: 40000,
      quantity: null,
      unitCost: null,
      soldElsewhere: 10000,
    );
    final stats = computeLotStats(
      lot: lot,
      products: const [],
      openOrders: const [],
      closedOrders: const [],
    );
    expect(stats.soldValue, 10000);
    expect(stats.garmentValue, 0);
    expect(stats.expectedValue, 10000);
    expect(stats.recoveryRemainingPercent, 75);
    expect(stats.currentProfit, 0);
    expect(stats.expectedProfit, 0);
  });

  test('app sales plus other channels cannot push recovery over 100', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final lot = testLot(
      id: 'l1',
      cost: 40000,
      quantity: 10,
      unitCost: 4000,
      soldElsewhere: 50000,
    );
    await store.upsertLot(lot);
    final product = testProduct(id: 'p1', lotId: 'l1', stock: 8, price: 15000);
    await store.upsertProduct(product);
    final order = await seedTestOrder(store, product: product);
    expect(store.closeOrder(order.id), isTrue);

    final stats = store.statsForLot(store.lotById('l1')!);
    expect(stats.soldValue, 65000);
    expect(stats.garmentValue, 120000);
    expect(stats.expectedValue, 170000);
    expect(stats.recoveryRemainingPercent, 0);
    expect(stats.currentProfit, 25000);
    expect(stats.expectedProfit, 130000);
  });
}
