import 'order.dart';
import 'product.dart';

class CompanyStats {
  const CompanyStats({
    required this.garmentUnits,
    required this.availableUnits,
    required this.reservedUnits,
    required this.garmentValue,
    required this.soldUnits,
    required this.soldValue,
  });

  final int garmentUnits;
  final int availableUnits;
  final int reservedUnits;
  final double garmentValue;
  final int soldUnits;
  final double soldValue;
}

DateTime startOfLocalDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime endOfLocalDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

({DateTime from, DateTime to}) inclusiveLocalDayRange(
  DateTime start,
  DateTime end,
) {
  final from = startOfLocalDay(start);
  final to = endOfLocalDay(end);
  if (to.isBefore(from)) {
    return (from: startOfLocalDay(end), to: endOfLocalDay(start));
  }
  return (from: from, to: to);
}

({DateTime from, DateTime to}) currentMonthLocalRange([DateTime? now]) {
  final today = now ?? DateTime.now();
  return inclusiveLocalDayRange(DateTime(today.year, today.month, 1), today);
}

bool isWithinInclusiveRange(DateTime date, DateTime? from, DateTime? to) {
  if (from == null && to == null) return true;
  final value = date.toUtc();
  if (from != null && value.isBefore(from.toUtc())) return false;
  if (to != null && value.isAfter(to.toUtc())) return false;
  return true;
}

CompanyStats computeCompanyStats({
  required List<Product> products,
  required List<DraftOrder> openOrders,
  required List<DraftOrder> closedOrders,
  DateTime? from,
  DateTime? to,
}) {
  final live = [
    for (final product in products)
      if (!product.isDeleted) product,
  ];
  final byId = {for (final product in live) product.id: product};

  final availableUnits = live.fold(0, (sum, product) => sum + product.stock);
  final availableValue = live.fold<double>(
    0,
    (sum, product) => sum + product.price * product.stock,
  );

  var reservedUnits = 0;
  var reservedValue = 0.0;
  for (final order in openOrders) {
    if (order.isDeleted || !order.isActive) continue;
    final linesByKey = {for (final line in order.lines) line.lineKey: line};
    for (final hold in order.stockReservations) {
      final product = byId[hold.productId];
      if (product == null || hold.quantity <= 0) continue;
      reservedUnits += hold.quantity;
      final line = linesByKey[hold.key];
      reservedValue += (line?.unitPrice ?? product.price) * hold.quantity;
    }
  }

  var soldUnits = 0;
  var soldValue = 0.0;
  for (final order in closedOrders) {
    if (order.isDeleted || !order.isClosed) continue;
    final soldAt = order.closedAt ?? order.createdAt;
    if (!isWithinInclusiveRange(soldAt, from, to)) continue;
    for (final line in order.lines) {
      if (line.quantity <= 0) continue;
      soldUnits += line.quantity;
      soldValue += line.lineTotal;
    }
  }

  return CompanyStats(
    garmentUnits: availableUnits + reservedUnits,
    availableUnits: availableUnits,
    reservedUnits: reservedUnits,
    garmentValue: availableValue + reservedValue,
    soldUnits: soldUnits,
    soldValue: soldValue,
  );
}
