import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/models/record_source.dart';

import 'fakes/catalog_harness.dart';

void main() {
  final stamp = DateTime.utc(2026, 9, 11, 12);
  final product = testProduct(createdAt: stamp, updatedAt: stamp);
  final customer = testCustomer(createdAt: stamp, updatedAt: stamp);

  test('DraftOrder.fromMap reads sync fields, lines and totals', () {
    final order = DraftOrder.fromMap('o1', {
      'id': 'o1',
      'orderNumber': 'PED-1',
      'status': 'borrador',
      'ivaEnabled': true,
      'ivaPercent': 10.5,
      'closedAt': null,
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
      'customer': customer.toMap(),
      'lines': [
        {
          'quantity': 2,
          'product': product.toMap(),
          'variant': product.variants.first.toMap(),
        },
      ],
    });
    expect(order.id, 'o1');
    expect(order.orderNumber, 'PED-1');
    expect(order.status, OrderStatus.borrador);
    expect(order.isActive, isTrue);
    expect(order.customer.name, 'Mónica Fernández');
    expect(order.lines, hasLength(1));
    expect(order.itemCount, 2);
    expect(order.subtotal, 20000);
    expect(order.iva, closeTo(2100, 0.001));
    expect(order.createdAt, stamp);
    expect(order.updatedAt, stamp);
    expect(order.deletedAt, isNull);
    expect(
      order.toMap().keys,
      containsAll([
        'id',
        'createdAt',
        'updatedAt',
        'deletedAt',
        'orderNumber',
        'status',
        'lines',
        'customer',
      ]),
    );
    expect(order.toMap()['status'], 'borrador');
    expect(order.toMap()['deletedAt'], isNull);
    expect(order.source, RecordSource.staff);
    expect(order.isCatalog, isFalse);
    expect(order.stockReservations, isEmpty);
    expect(order.stockNeedsSave, isTrue);
  });

  test('stock reservations round-trip and track unsaved edits', () {
    final order = DraftOrder.fromMap('o1', {
      'id': 'o1',
      'orderNumber': 'PED-1',
      'status': 'borrador',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'customer': customer.toMap(),
      'lines': [
        {
          'quantity': 2,
          'product': product.toMap(),
          'variant': product.variants.first.toMap(),
        },
      ],
      'stockReservations': [
        {'productId': product.id, 'size': 'M', 'color': 'Negro', 'quantity': 2},
      ],
    });
    expect(order.stockNeedsSave, isFalse);
    expect(order.reservedQuantity(product.id, 'M', 'Negro'), 2);
    expect(order.toMap()['stockReservations'], [
      {'productId': product.id, 'size': 'M', 'color': 'Negro', 'quantity': 2},
    ]);

    order.lines.first = order.lines.first.copyWith(quantity: 3);
    expect(order.stockNeedsSave, isTrue);
  });

  test('DraftOrder.fromMap reads a closed order snapshot', () {
    final closedAt = DateTime.utc(2026, 9, 12, 9);
    final order = DraftOrder.fromMap('o2', {
      'id': 'o2',
      'orderNumber': 'PED-2',
      'status': 'cerrado',
      'ivaEnabled': false,
      'ivaPercent': 21,
      'closedAt': closedAt.toIso8601String(),
      'createdAt': stamp.toIso8601String(),
      'updatedAt': closedAt.toIso8601String(),
      'deletedAt': null,
      'customer': customer.toMap(),
      'lines': [
        {
          'quantity': 1,
          'product': product.toMap(),
          'variant': product.variants.first.toMap(),
        },
      ],
    });
    expect(order.isClosed, isTrue);
    expect(order.closedAt, closedAt);
    expect(order.iva, 0);
    expect(order.toMap()['status'], 'cerrado');
    expect(order.toMap()['closedAt'], closedAt.toIso8601String());
  });

  test('OrderStatus.fromStorage rejects an unknown value', () {
    expect(() => OrderStatus.fromStorage('facturado'), throwsFormatException);
  });

  test('DraftOrder.fromMap reads a catalog source', () {
    final order = DraftOrder.fromMap('o3', {
      'id': 'o3',
      'orderNumber': 'WEB-ABCDEF',
      'status': 'borrador',
      'ivaEnabled': false,
      'ivaPercent': 21,
      'closedAt': null,
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
      'source': 'catalog',
      'customer': customer.toMap(),
      'lines': [
        {
          'quantity': 1,
          'product': product.toMap(),
          'variant': product.variants.first.toMap(),
        },
      ],
    });
    expect(order.isCatalog, isTrue);
    expect(order.toMap()['source'], 'catalog');
  });
}
