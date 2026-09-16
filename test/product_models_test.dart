import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/models/sync_record.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_product_access.dart';

void main() {
  final stamp = DateTime.utc(2026, 9, 11, 12);

  test('SyncRecord map always includes id and clock fields', () {
    final record = SyncRecord(id: 'p1', createdAt: stamp, updatedAt: stamp);
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

  test('garment swatches are common distinct colors', () {
    final names = [for (final color in Swatches.all) color.name];
    expect(Swatches.all.length, greaterThanOrEqualTo(12));
    expect(names.toSet().length, Swatches.all.length);
    expect(names, containsAll(['Negro', 'Blanco', 'Gris', 'Beige', 'Marrón']));
    expect(names, isNot(contains('Óxido')));
    expect(names, isNot(contains('Terracota')));
    expect(Swatches.marron.isCustom, isFalse);
    expect(Swatches.resolve('Lila').isCustom, isTrue);
    expect(Swatches.resolve('Negro'), Swatches.negro);
  });

  test('categories split clothing from footwear', () {
    expect(ApparelCategory.remeras.line, ApparelLine.ropa);
    expect(ApparelCategory.zapatillas.line, ApparelLine.calzado);
    expect(ApparelCategory.pantuflas.line, ApparelLine.calzado);
    expect(ApparelCategory.botas.label, 'Botas');
    expect(
      ApparelCategory.forLine(ApparelLine.calzado),
      containsAll([
        ApparelCategory.zapatillas,
        ApparelCategory.botas,
        ApparelCategory.pantuflas,
      ]),
    );
    expect(
      ApparelCategory.forLine(ApparelLine.ropa),
      isNot(contains(ApparelCategory.zapatillas)),
    );
    expect(
      ApparelCategory.forLine(ApparelLine.ropa).length,
      greaterThanOrEqualTo(20),
    );
  });

  test('garment sizes are common distinct values', () {
    expect(ApparelSizes.all.length, greaterThanOrEqualTo(12));
    expect(ApparelSizes.all.toSet().length, ApparelSizes.all.length);
    expect(
      ApparelSizes.all,
      containsAll(['XS', 'S', 'M', 'L', 'XL', 'XXL', 'Único']),
    );
    expect(ApparelSizes.isCustom('M'), isFalse);
    expect(ApparelSizes.isCustom('44'), isTrue);
    expect(ApparelSizes.resolve('M'), 'M');
    expect(ApparelSizes.resolve('Oversize'), 'Oversize');
  });

  test('upsert writes products with sync fields', () async {
    final access = FakeProductAccess();
    final store = AppStore(products: access);
    addTearDown(store.dispose);
    store.bindCompany('co1');
    final product = testProduct();
    await store.upsertProduct(product);
    final saved = access.products['co1']![product.id]!;
    expect(
      saved.toMap().keys,
      containsAll(['id', 'createdAt', 'updatedAt', 'deletedAt']),
    );
    expect(saved.id, product.id);
    expect(saved.deletedAt, isNull);
    expect(saved.createdAt, product.createdAt);
  });
}
