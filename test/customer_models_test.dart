import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/customer.dart';

void main() {
  final stamp = DateTime.utc(2026, 9, 11, 12);

  test('Customer.fromMap reads sync fields from the document', () {
    final customer = Customer.fromMap('c1', {
      'id': 'c1',
      'name': 'Mónica Fernández',
      'cuit': '27-21543678-3',
      'taxCondition': 'responsableInscripto',
      'phone': '+54 9 11 4555-0101',
      'address': 'Av. Rivadavia 1234',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(customer.id, 'c1');
    expect(customer.name, 'Mónica Fernández');
    expect(customer.cuit, '27-21543678-3');
    expect(customer.taxCondition, TaxCondition.responsableInscripto);
    expect(customer.phone, '+54 9 11 4555-0101');
    expect(customer.address, 'Av. Rivadavia 1234');
    expect(customer.createdAt, stamp);
    expect(customer.updatedAt, stamp);
    expect(customer.deletedAt, isNull);
    expect(customer.isDeleted, isFalse);
    expect(
      customer.toMap().keys,
      containsAll(['id', 'createdAt', 'updatedAt', 'deletedAt', 'name']),
    );
    expect(customer.toMap()['taxCondition'], 'responsableInscripto');
    expect(customer.toMap()['deletedAt'], isNull);
  });

  test('Customer.fromMap treats blank optional fields as null', () {
    final customer = Customer.fromMap('c2', {
      'id': 'c2',
      'name': 'Ana',
      'cuit': '  ',
      'taxCondition': '',
      'phone': '',
      'address': null,
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(customer.cuit, isNull);
    expect(customer.taxCondition, isNull);
    expect(customer.phone, isNull);
    expect(customer.address, isNull);
    expect(customer.toMap()['taxCondition'], isNull);
  });
}
