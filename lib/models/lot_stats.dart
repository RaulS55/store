import 'lot.dart';
import 'order.dart';
import 'product.dart';

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
  final assigned = [
    for (final product in products)
      if (!product.isDeleted && product.lotId == lot.id) product,
  ];
  final byId = {for (final product in assigned) product.id: product};

  final availableUnits = assigned.fold(
    0,
    (sum, product) => sum + product.stock,
  );
  final availableValue = assigned.fold<double>(
    0,
    (sum, product) => sum + product.price * product.stock,
  );

  var reservedUnits = 0;
  var reservedValue = 0.0;
  for (final order in openOrders) {
    if (order.isDeleted || !order.isActive) continue;
    for (final hold in order.stockReservations) {
      final product = byId[hold.productId];
      if (product == null || hold.quantity <= 0) continue;
      reservedUnits += hold.quantity;
      reservedValue += product.price * hold.quantity;
    }
  }

  var soldUnits = 0;
  var soldValue = 0.0;
  for (final order in closedOrders) {
    if (order.isDeleted || !order.isClosed) continue;
    for (final line in order.lines) {
      if (!byId.containsKey(line.product.id)) continue;
      soldUnits += line.quantity;
      soldValue += line.lineTotal;
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

double _remainingPercent(double cost, double recovered) {
  if (cost <= 0) return 0;
  final remaining = (cost - recovered) / cost * 100;
  if (remaining <= 0) return 0;
  if (remaining >= 100) return 100;
  return remaining;
}
