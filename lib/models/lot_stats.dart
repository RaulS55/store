import 'lot.dart';
import 'order.dart';
import 'product.dart';
import 'stock_layer.dart';

class LotStats {
  const LotStats({
    required this.garmentUnits,
    required this.availableUnits,
    required this.reservedUnits,
    required this.soldUnits,
    required this.unitPrice,
    required this.soldValue,
    required this.reservedValue,
    required this.garmentValue,
    required this.expectedValue,
    required this.recoveryRemainingPercent,
    required this.currentProfit,
    required this.expectedProfit,
  });

  final int garmentUnits;
  final int availableUnits;
  final int reservedUnits;
  final int soldUnits;
  final double? unitPrice;
  final double soldValue;
  final double reservedValue;
  final double garmentValue;
  final double expectedValue;
  final double recoveryRemainingPercent;
  final double currentProfit;
  final double expectedProfit;
}

LotStats computeLotStats({
  required Lot lot,
  required List<Product> products,
  required List<DraftOrder> openOrders,
  required List<DraftOrder> closedOrders,
}) {
  final live = <String, Product>{};
  for (final product in products) {
    if (product.isDeleted) continue;
    live[product.id] = product;
  }

  var availableUnits = 0;
  var availableValue = 0.0;
  for (final product in live.values) {
    final units = product.unitsInLot(lot.id);
    if (units <= 0) continue;
    availableUnits += units;
    availableValue += product.sellingPrice * units;
  }

  var reservedUnits = 0;
  var reservedValue = 0.0;
  for (final order in openOrders) {
    if (order.isDeleted || !order.isActive) continue;
    final linesByKey = {for (final line in order.lines) line.lineKey: line};
    for (final hold in order.stockReservations) {
      if (hold.quantity <= 0) continue;
      final product = live[hold.productId];
      if (product == null) continue;
      final line = linesByKey[hold.key];
      final units = unitsForLot(
        lotId: lot.id,
        hold: hold,
        line: line,
        product: product,
      );
      if (units <= 0) continue;
      reservedUnits += units;
      final unitPrice = line?.unitPrice ?? product.sellingPrice;
      reservedValue += unitPrice * units;
    }
  }

  var soldUnits = 0;
  var soldValue = 0.0;
  for (final order in closedOrders) {
    if (order.isDeleted || !order.isClosed) continue;
    final holdsByKey = {
      for (final hold in order.stockReservations) hold.key: hold,
    };
    for (final line in order.lines) {
      if (line.quantity <= 0) continue;
      final product = live[line.product.id];
      if (product == null) continue;
      final units = unitsForLot(
        lotId: lot.id,
        hold: holdsByKey[line.lineKey],
        line: line,
        product: product,
      );
      if (units <= 0) continue;
      soldUnits += units;
      soldValue += line.unitPrice * units;
    }
  }

  final appSales = soldValue;
  final recovered = appSales + lot.soldElsewhere;
  final garmentValue = availableValue + reservedValue + appSales;
  final expectedValue = garmentValue + lot.soldElsewhere;
  final quantity = lot.quantity;
  final unitPrice = quantity != null && quantity > 0
      ? lot.derivedUnitCost
      : null;

  return LotStats(
    garmentUnits: availableUnits + reservedUnits + soldUnits,
    availableUnits: availableUnits,
    reservedUnits: reservedUnits,
    soldUnits: soldUnits,
    unitPrice: unitPrice,
    soldValue: recovered,
    reservedValue: reservedValue,
    garmentValue: garmentValue,
    expectedValue: expectedValue,
    recoveryRemainingPercent: _remainingPercent(lot.cost, recovered),
    currentProfit: recovered > lot.cost ? recovered - lot.cost : 0,
    expectedProfit: expectedValue > lot.cost ? expectedValue - lot.cost : 0,
  );
}

/// Units of [lotId] in a reservation, or in the line when the order is older
/// and does not record which lot the units came from.
int unitsForLot({
  required String lotId,
  required StockReservation? hold,
  required OrderLine? line,
  required Product? product,
}) {
  final allocations = hold?.allocations ?? const <LotAllocation>[];
  if (allocations.any((allocation) => allocation.quantity > 0)) {
    var sum = 0;
    for (final allocation in allocations) {
      if (allocation.lotId == lotId && allocation.quantity > 0) {
        sum += allocation.quantity;
      }
    }
    return sum;
  }
  final snapshot = line?.product.lotId.trim() ?? '';
  final fallback = snapshot.isNotEmpty
      ? snapshot
      : (product?.persistedLotId ?? '');
  if (fallback != lotId) return 0;
  if (hold != null) return hold.quantity;
  return line?.quantity ?? 0;
}

double _remainingPercent(double cost, double recovered) {
  if (cost <= 0) return 0;
  final remaining = (cost - recovered) / cost * 100;
  if (remaining <= 0) return 0;
  if (remaining >= 100) return 100;
  return remaining;
}
