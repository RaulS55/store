import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/models/sync_record.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_product_access.dart';

void main() {
  final stamp = DateTime.utc(2026, 9, 11, 12);

  test('SyncRecord map always includes id and clock fields', () {
    final record = SyncRecord(
      id: 'p1',
      createdAt: stamp,
      updatedAt: stamp,
    );
    expect(record.toMap(), {
      'id': 'p1',
      'createdAt': '2026-09-11T12:00:00.000Z',
      'updatedAt': '2026-09-11T12:00:00.000Z',
      'deletedAt': null,
    });
    expect(record.isDeleted, isFalse);
  });

  test('Product.fromMap reads sync fields from the document', () {
    final product = Product.fromMap('p1', {
      'id': 'p1',
      'name': 'Remera',
      'sku': 'RM-1',
      'category': 'remeras',
      'brand': 'Test',
      'price': 10000,
      'images': <String>[],
      'variants': [
        {'size': 'M', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 4},
      ],
      'status': 'activo',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(product.id, 'p1');
    expect(product.createdAt, stamp);
    expect(product.updatedAt, stamp);
    expect(product.deletedAt, isNull);
    expect(product.toMap()['id'], 'p1');
    expect(product.toMap().containsKey('deletedAt'), isTrue);
  });

  test('upsert writes products with sync fields', () async {
    final access = FakeProductAccess();
    final store = AppStore(products: access);
    addTearDown(store.dispose);
    store.bindCompany('co1');
    final product = testProduct();
    await store.upsertProduct(product);
    final saved = access.products['co1']![product.id]!;
    expect(saved.toMap().keys, containsAll(['id', 'createdAt', 'updatedAt', 'deletedAt']));
    expect(saved.id, product.id);
    expect(saved.deletedAt, isNull);
    expect(saved.createdAt, product.createdAt);
  });
}
