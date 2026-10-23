import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/expense.dart';

void main() {
  final stamp = DateTime.utc(2026, 9, 11, 12);

  test('Expense.fromMap reads amount and note', () {
    final expense = Expense.fromMap('e1', {
      'id': 'e1',
      'amount': 15000,
      'note': ' Viaje ',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(expense.id, 'e1');
    expect(expense.amount, 15000);
    expect(expense.note, 'Viaje');
    expect(expense.displayName, 'Viaje');
    expect(expense.toMap()['amount'], 15000);
    expect(expense.toMap()['note'], 'Viaje');
  });

  test('expense without note uses a default display name', () {
    final expense = Expense(
      id: 'e1',
      amount: 8000,
      createdAt: stamp,
      updatedAt: stamp,
    );
    expect(expense.displayName, 'Otro gasto');
  });
}
