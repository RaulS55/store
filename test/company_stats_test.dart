import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/company_stats.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/models/product.dart';

import 'fakes/catalog_harness.dart';

DraftOrder closedOrder({
  required Product product,
  required int quantity,
  required DateTime closedAt,
  String id = 'o-closed',
  double? unitPriceOverride,
}) {
  return DraftOrder(
    id: id,
    orderNumber: id,
    customer: testCustomer(),
    lines: [
      OrderLine(
        product: product,
        variant: product.variants.first,
        quantity: quantity,
        unitPriceOverride: unitPriceOverride,
      ),
    ],
    status: OrderStatus.cerrado,
    createdAt: closedAt,
    updatedAt: closedAt,
    closedAt: closedAt,
  );
}

void main() {
  test('empty catalog has no garments and no sales', () {
    final stats = computeCompanyStats(
      products: const [],
      openOrders: const [],
      closedOrders: const [],
    );
    expect(stats.garmentUnits, 0);
    expect(stats.availableUnits, 0);
    expect(stats.reservedUnits, 0);
    expect(stats.garmentValue, 0);
    expect(stats.soldUnits, 0);
    expect(stats.soldValue, 0);
  });

  test('available garments add units and retail value', () {
    final stats = computeCompanyStats(
      products: [
        testProduct(id: 'p1', stock: 8, price: 15000),
        testProduct(id: 'p2', stock: 2, price: 20000),
      ],
      openOrders: const [],
      closedOrders: const [],
    );
    expect(stats.garmentUnits, 10);
    expect(stats.availableUnits, 10);
    expect(stats.reservedUnits, 0);
    expect(stats.garmentValue, 160000);
    expect(stats.soldUnits, 0);
    expect(stats.soldValue, 0);
  });

  test('deleted products are ignored', () {
    final stats = computeCompanyStats(
      products: [
        testProduct(id: 'p1', stock: 8, price: 15000),
        testProduct(
          id: 'p2',
          stock: 4,
          price: 20000,
          deletedAt: DateTime.utc(2026, 9, 11),
        ),
      ],
      openOrders: const [],
      closedOrders: const [],
    );
    expect(stats.garmentUnits, 8);
    expect(stats.garmentValue, 120000);
  });

  test('closed orders count sold garments and keep remaining stock', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final product = testProduct(id: 'p1', stock: 8, price: 15000);
    await store.upsertProduct(product);
    final order = await seedTestOrder(store, product: product);
    expect(store.closeOrder(order.id), isTrue);

    final stats = store.statsForCompany();
    expect(stats.soldUnits, 1);
    expect(stats.availableUnits, 7);
    expect(stats.reservedUnits, 0);
    expect(stats.garmentUnits, 7);
    expect(stats.soldValue, 15000);
    expect(stats.garmentValue, 105000);
  });

  test('reserved stock counts as garments still in the store', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final product = testProduct(id: 'p1', stock: 8, price: 15000);
    await store.upsertProduct(product);
    final order = await seedTestOrder(store, product: product);
    store.setLineQty(order.id, order.lines.first.lineKey, 2);
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);

    final stats = store.statsForCompany();
    expect(stats.availableUnits, 6);
    expect(stats.reservedUnits, 2);
    expect(stats.garmentUnits, 8);
    expect(stats.soldUnits, 0);
    expect(stats.garmentValue, 120000);
    expect(stats.soldValue, 0);
  });

  test('sold totals use the sale override instead of list price', () {
    final product = testProduct(id: 'p1', stock: 7, price: 15000);
    final stats = computeCompanyStats(
      products: [product],
      openOrders: const [],
      closedOrders: [
        closedOrder(
          product: product,
          quantity: 1,
          closedAt: DateTime.utc(2026, 9, 20),
          unitPriceOverride: 10000,
        ),
      ],
    );
    expect(stats.soldUnits, 1);
    expect(stats.soldValue, 10000);
    expect(stats.garmentUnits, 7);
    expect(stats.garmentValue, 105000);
  });

  test('date range keeps current stock and filters sold by closedAt', () {
    final product = testProduct(id: 'p1', stock: 5, price: 10000);
    final march = closedOrder(
      id: 'o-march',
      product: product,
      quantity: 2,
      closedAt: DateTime.utc(2026, 3, 10, 15),
    );
    final september = closedOrder(
      id: 'o-sept',
      product: product,
      quantity: 1,
      closedAt: DateTime.utc(2026, 9, 15, 18),
    );
    final all = computeCompanyStats(
      products: [product],
      openOrders: const [],
      closedOrders: [march, september],
    );
    expect(all.garmentUnits, 5);
    expect(all.soldUnits, 3);
    expect(all.soldValue, 30000);

    final range = currentMonthLocalRange(DateTime(2026, 9, 29));
    final month = computeCompanyStats(
      products: [product],
      openOrders: const [],
      closedOrders: [march, september],
      from: range.from,
      to: range.to,
    );
    expect(month.garmentUnits, 5);
    expect(month.soldUnits, 1);
    expect(month.soldValue, 10000);

    final custom = inclusiveLocalDayRange(
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 31),
    );
    final marchStats = computeCompanyStats(
      products: [product],
      openOrders: const [],
      closedOrders: [march, september],
      from: custom.from,
      to: custom.to,
    );
    expect(marchStats.soldUnits, 2);
    expect(marchStats.soldValue, 20000);
    expect(marchStats.garmentUnits, 5);
  });

  test('inclusive day range covers the whole local day', () {
    final range = inclusiveLocalDayRange(
      DateTime(2026, 9, 15, 10),
      DateTime(2026, 9, 15, 18),
    );
    expect(
      isWithinInclusiveRange(DateTime(2026, 9, 15, 8), range.from, range.to),
      isTrue,
    );
    expect(
      isWithinInclusiveRange(DateTime(2026, 9, 14, 23, 59), range.from, range.to),
      isFalse,
    );
    expect(
      isWithinInclusiveRange(DateTime(2026, 9, 16), range.from, range.to),
      isFalse,
    );
  });
}
