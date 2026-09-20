import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/lot.dart';

void main() {
  final stamp = DateTime.utc(2026, 9, 11, 12);

  test('Lot.fromMap reads cost, quantity and soldElsewhere', () {
    final lot = Lot.fromMap('l1', {
      'id': 'l1',
      'name': ' Feria marzo ',
      'cost': 150000,
      'quantity': 30,
      'unitCost': 5000,
      'soldElsewhere': 20000,
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(lot.id, 'l1');
    expect(lot.name, 'Feria marzo');
    expect(lot.displayName, 'Feria marzo');
    expect(lot.cost, 150000);
    expect(lot.quantity, 30);
    expect(lot.unitCost, 5000);
    expect(lot.derivedUnitCost, 5000);
    expect(lot.soldElsewhere, 20000);
    expect(lot.toMap()['cost'], 150000);
    expect(lot.toMap()['quantity'], 30);
  });

  test('unnamed lot uses the created date as display name', () {
    final lot = Lot(id: 'l1', cost: 10000, createdAt: stamp, updatedAt: stamp);
    expect(lot.displayName, 'Montón · 11/09/2026');
  });

  test(
    'derived unit cost uses cost over quantity when unitCost is missing',
    () {
      final lot = Lot(
        id: 'l1',
        cost: 10000,
        quantity: 4,
        createdAt: stamp,
        updatedAt: stamp,
      );
      expect(lot.derivedUnitCost, 2500);
    },
  );

  test('zero or missing quantity is stored as null', () {
    final lot = Lot.fromMap('l1', {
      'id': 'l1',
      'name': '',
      'cost': 8000,
      'quantity': 0,
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(lot.quantity, isNull);
    expect(lot.derivedUnitCost, isNull);
    expect(lot.soldElsewhere, 0);
  });
}
