import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/lot_stats.dart';

import 'fakes/catalog_harness.dart';

void main() {
  test('unsold lot with no garments still has the full cost to recover', () {
    final lot = testLot(cost: 40000, quantity: null, unitCost: null);
    final stats = computeLotStats(
      lot: lot,
      products: const [],
      closedOrders: const [],
    );
    expect(stats.productCount, 0);
    expect(stats.stockUnits, 0);
    expect(stats.soldUnits, 0);
    expect(stats.retailStockValue, 0);
    expect(stats.recovered, 0);
    expect(stats.remainingToRecover, 40000);
    expect(stats.profit, -40000);
  });

  test('assigned garments add their retail stock value', () {
    final lot = testLot(id: 'l1', cost: 40000, quantity: 10, unitCost: 4000);
    final stats = computeLotStats(
      lot: lot,
      products: [testProduct(lotId: 'l1', stock: 8, price: 15000)],
      closedOrders: const [],
    );
    expect(stats.productCount, 1);
    expect(stats.stockUnits, 8);
    expect(stats.retailStockValue, 120000);
    expect(stats.effectiveUnitCost, 4000);
    expect(stats.recovered, 0);
    expect(stats.remainingToRecover, 40000);
    expect(stats.profit, -40000);
  });

  test(
    'closed orders recover sale price and reduce remaining to recover',
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
      expect(stats.stockUnits, 7);
      expect(stats.appSales, 15000);
      expect(stats.recovered, 15000);
      expect(stats.retailStockValue, 105000);
      expect(stats.remainingToRecover, 25000);
      expect(stats.profit, -25000);
    },
  );

  test('soldElsewhere counts as recovered money and can become profit', () {
    final lot = testLot(
      cost: 40000,
      quantity: null,
      unitCost: null,
      soldElsewhere: 50000,
    );
    final stats = computeLotStats(
      lot: lot,
      products: const [],
      closedOrders: const [],
    );
    expect(stats.recovered, 50000);
    expect(stats.remainingToRecover, 0);
    expect(stats.profit, 10000);
  });

  test('without quantity, unit cost uses stock plus sold units', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final lot = testLot(id: 'l1', cost: 40000, quantity: null, unitCost: null);
    await store.upsertLot(lot);
    final product = testProduct(id: 'p1', lotId: 'l1', stock: 8, price: 12000);
    await store.upsertProduct(product);
    final order = await seedTestOrder(store, product: product);
    expect(store.closeOrder(order.id), isTrue);

    final stats = store.statsForLot(store.lotById('l1')!);
    expect(stats.soldUnits, 1);
    expect(stats.stockUnits, 7);
    expect(stats.effectiveUnitCost, 5000);
    expect(stats.retailStockValue, 84000);
    expect(stats.remainingToRecover, 28000);
    expect(stats.profit, -28000);
  });
}
