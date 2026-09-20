import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/map_value.dart';
import 'package:store_app/models/order.dart';

import 'fakes/catalog_harness.dart';

void main() {
  test('coerceStringKeyMap copies nested maps into a Dart map', () {
    final product = testProduct(id: 'p1');
    final customer = testCustomer(id: 'c1');
    final order = DraftOrder(
      id: 'o1',
      orderNumber: 'P-1',
      customer: customer,
      lines: [
        OrderLine(
          product: product,
          variant: product.variants.first,
          quantity: 2,
        ),
      ],
    );

    final coerced = coerceStringKeyMap(order.toMap());
    final parsed = DraftOrder.fromMap('o1', coerced);
    expect(parsed.id, 'o1');
    expect(parsed.customer.id, 'c1');
    expect(parsed.lines.single.quantity, 2);
    expect(parsed.lines.single.product.id, 'p1');
  });

  test('catalog encode/decode keeps order fields', () {
    final product = testProduct(id: 'p1');
    final order = DraftOrder(
      id: 'o1',
      orderNumber: 'P-1',
      customer: testCustomer(id: 'c1'),
      lines: [
        OrderLine(
          product: product,
          variant: product.variants.first,
          quantity: 1,
        ),
      ],
    );
    final encoded = encodeCatalogMap(order.toMap());
    expect(encoded, isA<String>());
    final decoded = decodeCatalogMap(encoded);
    expect(DraftOrder.fromMap('o1', decoded!).orderNumber, 'P-1');
  });
}
