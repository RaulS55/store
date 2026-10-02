import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/models/product.dart';
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
    expect(order.includeProductCodeInInvoice, isTrue);
    expect(order.sena, isNull);
    expect(order.hasSena, isFalse);
    expect(order.toMap().containsKey('sena'), isFalse);
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

  test('sortedLines groups by color and then size ascending', () {
    OrderLine line(String size, String color) {
      return OrderLine(
        product: product,
        variant: ProductVariant(
          size: size,
          color: color,
          colorHex: color == 'Rojo' ? '#C62828' : '#1E1E1E',
          stock: 4,
        ),
        quantity: 1,
      );
    }

    final order = DraftOrder(
      id: 'o-sort',
      orderNumber: 'PED-9',
      customer: customer,
      lines: [
        line('M', 'Negro'),
        line('S', 'Negro'),
        line('L', 'Negro'),
        line('S', 'Rojo'),
      ],
    );
    expect(
      [
        for (final item in order.sortedLines)
          '${item.variant.color} ${item.variant.size}',
      ],
      ['Negro S', 'Negro M', 'Negro L', 'Rojo S'],
    );
  });

  test('OrderStatus.fromStorage rejects an unknown value', () {
    expect(() => OrderStatus.fromStorage('facturado'), throwsFormatException);
  });

  test('OrderLine keeps list price and uses an optional sale override', () {
    final line = OrderLine(
      product: product,
      variant: product.variants.first,
      quantity: 2,
    );
    expect(line.listPrice, 10000);
    expect(line.unitPrice, 10000);
    expect(line.hasCustomPrice, isFalse);
    expect(line.lineTotal, 20000);
    expect(line.toMap().containsKey('unitPriceOverride'), isFalse);

    final discounted = line.copyWith(unitPriceOverride: 8000);
    expect(discounted.listPrice, 10000);
    expect(discounted.unitPrice, 8000);
    expect(discounted.hasCustomPrice, isTrue);
    expect(discounted.lineTotal, 16000);
    expect(discounted.toMap()['unitPriceOverride'], 8000);

    final restored = discounted.copyWith(clearUnitPriceOverride: true);
    expect(restored.hasCustomPrice, isFalse);
    expect(restored.unitPrice, 10000);
    expect(restored.toMap().containsKey('unitPriceOverride'), isFalse);
  });

  test('OrderLine.fromMap reads a missing override as list price', () {
    final line = OrderLine.fromMap({
      'quantity': 1,
      'product': product.toMap(),
      'variant': product.variants.first.toMap(),
    });
    expect(line.unitPriceOverride, isNull);
    expect(line.unitPrice, product.price);

    final custom = OrderLine.fromMap({
      'quantity': 1,
      'product': product.toMap(),
      'variant': product.variants.first.toMap(),
      'unitPriceOverride': 7500,
    });
    expect(custom.unitPriceOverride, 7500);
    expect(custom.unitPrice, 7500);
    expect(custom.listPrice, product.price);
  });

  test('DraftOrder subtotal uses the sale price when a line is overridden', () {
    final order = DraftOrder(
      id: 'o-price',
      orderNumber: 'PED-9',
      customer: customer,
      lines: [
        OrderLine(
          product: product,
          variant: product.variants.first,
          quantity: 2,
          unitPriceOverride: 8000,
        ),
      ],
    );
    expect(order.subtotal, 16000);
    expect(order.total, 16000);
  });

  test('DraftOrder reads a saved deposit and remaining balance', () {
    final order = DraftOrder.fromMap('o-sena', {
      'id': 'o-sena',
      'orderNumber': 'PED-10',
      'status': 'cerrado',
      'sena': 3000,
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'customer': customer.toMap(),
      'lines': [
        {
          'quantity': 1,
          'product': product.toMap(),
          'variant': product.variants.first.toMap(),
        },
      ],
    });
    expect(order.sena, 3000);
    expect(order.hasSena, isTrue);
    expect(order.total, 10000);
    expect(order.remaining, 7000);
    expect(order.toMap()['sena'], 3000);
  });

  test('DraftOrder.fromMap keeps a recorded zero deposit', () {
    final order = DraftOrder.fromMap('o-sena-0', {
      'id': 'o-sena-0',
      'orderNumber': 'PED-11',
      'status': 'borrador',
      'sena': 0,
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'customer': customer.toMap(),
      'lines': [
        {
          'quantity': 1,
          'product': product.toMap(),
          'variant': product.variants.first.toMap(),
        },
      ],
    });
    expect(order.sena, 0);
    expect(order.hasSena, isFalse);
    expect(order.toMap()['sena'], 0);
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

  test('OrderLine.mergeAdded sums the same variant and appends new ones', () {
    final shirt = testProduct(id: 'p-shirt', name: 'Remera');
    final jean = testProduct(id: 'p-jean', name: 'Jean');
    final current = [
      OrderLine(product: shirt, variant: shirt.variants.first, quantity: 2),
    ];
    final added = [
      OrderLine(product: shirt, variant: shirt.variants.first, quantity: 1),
      OrderLine(product: jean, variant: jean.variants.first, quantity: 3),
    ];
    final merged = OrderLine.mergeAdded(current, added);
    expect(merged, hasLength(2));
    expect(
      merged.firstWhere((line) => line.product.id == 'p-shirt').quantity,
      3,
    );
    expect(
      merged.firstWhere((line) => line.product.id == 'p-jean').quantity,
      3,
    );
  });
}
