import 'dart:math' as math;

import 'lot.dart';
import 'order.dart';
import 'product.dart';

class LotStats {
  const LotStats({
    required this.productCount,
    required this.stockUnits,
    required this.soldUnits,
    required this.retailStockValue,
    required this.appSales,
    required this.recovered,
    required this.effectiveUnitCost,
    required this.remainingToRecover,
    required this.profit,
  });

  final int productCount;
  final int stockUnits;
  final int soldUnits;
  final double retailStockValue;
  final double appSales;
  final double recovered;
  final double? effectiveUnitCost;
  final double remainingToRecover;
  final double profit;
}

LotStats computeLotStats({
  required Lot lot,
  required List<Product> products,
  required List<DraftOrder> closedOrders,
}) {
  final assigned = [
    for (final product in products)
      if (product.lotId == lot.id) product,
  ];
  final productIds = {for (final product in assigned) product.id};
  final stockUnits = assigned.fold(0, (sum, product) => sum + product.stock);
  final retailStockValue = assigned.fold<double>(
    0,
    (sum, product) => sum + product.price * product.stock,
  );

  var soldUnits = 0;
  var appSales = 0.0;
  for (final order in closedOrders) {
    for (final line in order.lines) {
      if (!productIds.contains(line.product.id)) continue;
      soldUnits += line.quantity;
      appSales += line.lineTotal;
    }
  }

  final recovered = appSales + lot.soldElsewhere;
  var unitCost = lot.derivedUnitCost;
  if (unitCost == null) {
    final denom = stockUnits + soldUnits;
    if (denom > 0) unitCost = lot.cost / denom;
  }

  return LotStats(
    productCount: assigned.length,
    stockUnits: stockUnits,
    soldUnits: soldUnits,
    retailStockValue: retailStockValue,
    appSales: appSales,
    recovered: recovered,
    effectiveUnitCost: unitCost,
    remainingToRecover: math.max(0.0, lot.cost - recovered),
    profit: recovered - lot.cost,
  );
}
