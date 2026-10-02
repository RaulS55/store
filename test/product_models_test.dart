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
    expect(product.category, ApparelCategory.remeras);
    expect(product.audience, isNull);
  });

  test('Product.fromMap treats an empty audience as optional', () {
    final product = Product.fromMap('p1', {
      'id': 'p1',
      'name': 'Remera',
      'sku': 'RM-1',
      'category': 'remeras',
      'audience': '',
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
    expect(product.audience, isNull);
    expect(product.audienceLabel, '');
    expect(product.toMap()['audience'], '');
  });

  test('Product.fromMap reads a stored audience', () {
    final product = Product.fromMap('p1', {
      'id': 'p1',
      'name': 'Remera',
      'sku': 'RM-1',
      'category': 'remeras',
      'audience': 'mujer',
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
    expect(product.audience, ApparelAudience.mujer);
    expect(product.audienceLabel, 'Mujer');
    expect(product.toMap()['audience'], 'mujer');
  });

  test('audience includes baby and youth', () {
    expect(ApparelAudience.fromStorage('bebe').label, 'Bebé');
    expect(ApparelAudience.fromStorage('juvenil').label, 'Juvenil');
    expect(
      [for (final audience in ApparelAudience.values) audience.label],
      containsAll(['Hombre', 'Mujer', 'Infantil', 'Bebé', 'Juvenil', 'Unisex']),
    );
  });

  test('Product.fromMap treats an empty category as optional', () {
    final product = Product.fromMap('p1', {
      'id': 'p1',
      'name': 'Remera',
      'sku': 'RM-1',
      'category': '',
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
    expect(product.category, isNull);
    expect(product.categoryLabel, '');
    expect(product.toMap()['category'], '');
  });

  test('ApparelCategory.match finds a label ignoring case', () {
    expect(ApparelCategory.match('remeras'), ApparelCategory.remeras);
    expect(ApparelCategory.match('Remeras'), ApparelCategory.remeras);
    expect(ApparelCategory.match(''), isNull);
    expect(ApparelCategory.tryFromStorage(''), isNull);
  });

  test('ApparelCategory keeps an unknown label as a custom category', () {
    final category = ApparelCategory.fromStorage('Pantalones cargo');
    expect(category.isCustom, isTrue);
    expect(category.label, 'Pantalones cargo');
    expect(ApparelCategory.resolve('Pantalones cargo'), category);
    expect(ApparelCategory.resolve('Remeras'), ApparelCategory.remeras);
    expect(ApparelCategory.resolve(''), isNull);
  });

  test('Product.fromMap keeps a custom category label', () {
    final product = Product.fromMap('p1', {
      'id': 'p1',
      'name': 'Cargo',
      'sku': 'CG-1',
      'category': 'Pantalones cargo',
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
    expect(product.category?.isCustom, isTrue);
    expect(product.categoryLabel, 'Pantalones cargo');
    expect(product.toMap()['category'], 'Pantalones cargo');
  });

  test('garment swatches are common distinct colors', () {
    final names = [for (final color in Swatches.all) color.name];
    expect(Swatches.all.length, greaterThanOrEqualTo(12));
    expect(names.toSet().length, Swatches.all.length);
    expect(names, containsAll(['Negro', 'Blanco', 'Gris', 'Beige', 'Marrón']));
    expect(names, contains('Celeste'));
    expect(Swatches.celeste.isCustom, isFalse);
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

  test('mergeVisible keeps used categories and custom extras', () {
    expect(
      ApparelCategory.mergeVisible(
        predefined: ApparelCategory.values,
        used: const [ApparelCategory.jeans, ApparelCategory.remeras],
      ),
      [ApparelCategory.remeras, ApparelCategory.jeans],
    );
    expect(
      ApparelCategory.mergeVisible(
        predefined: ApparelCategory.forLine(ApparelLine.calzado),
        used: [
          ApparelCategory.remeras,
          ApparelCategory.custom('Pantalones cargo'),
          ApparelCategory.botas,
        ],
      ),
      [ApparelCategory.botas, ApparelCategory.custom('Pantalones cargo')],
    );
    expect(
      ApparelCategory.mergeChoices(
        predefined: ApparelCategory.forLine(ApparelLine.calzado),
        used: [ApparelCategory.custom('Pantalones cargo')],
      ),
      containsAll([
        ApparelCategory.zapatillas,
        ApparelCategory.custom('Pantalones cargo'),
      ]),
    );
    expect(
      ApparelCategory.mergeVisible(
        predefined: ApparelCategory.values,
        used: const [
          ApparelCategory.remeras,
          ApparelCategory.jeans,
          ApparelCategory.jeans,
          ApparelCategory.musculosas,
        ],
      ),
      [
        ApparelCategory.jeans,
        ApparelCategory.remeras,
        ApparelCategory.musculosas,
      ],
    );
  });

  test('equivalent size falls back to the garment size', () {
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
        {'size': 'L', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 2},
      ],
      'status': 'activo',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(product.equivalentSizes, isEmpty);
    expect(product.equivalentSizeFor('M'), 'M');
    expect(product.equivalentSizeFor('L'), 'L');
    expect(product.equivalentSizeLabel, 'M / L');
    expect(product.toMap()['equivalentSizes'], isEmpty);
  });

  test('Product.fromMap reads stored equivalent sizes', () {
    final product = Product.fromMap('p1', {
      'id': 'p1',
      'name': 'Remera',
      'sku': 'RM-1',
      'category': 'remeras',
      'brand': 'Test',
      'price': 10000,
      'images': <String>[],
      'equivalentSizes': {'M': '38', 'L': '  '},
      'variants': [
        {'size': 'M', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 4},
        {'size': 'L', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 2},
      ],
      'status': 'activo',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(product.equivalentSizeFor('M'), '38');
    expect(product.equivalentSizeFor('L'), 'L');
    expect(product.equivalentSizeLabel, '38 / L');
    expect(product.toMap()['equivalentSizes'], {'M': '38'});
  });

  test('garment sizes sort ascending and keep equivalent pairs', () {
    final product = Product.fromMap('p1', {
      'id': 'p1',
      'name': 'Remera',
      'sku': 'RM-1',
      'category': 'remeras',
      'brand': 'Test',
      'price': 10000,
      'images': <String>[],
      'equivalentSizes': {'L': '42', 'XXS': '34', 'M': '38', 'XL': '44'},
      'variants': [
        {'size': 'L', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 2},
        {'size': 'XXS', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 1},
        {'size': 'XL', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 3},
        {'size': 'M', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 4},
      ],
      'status': 'activo',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(product.sizes, ['XXS', 'M', 'L', 'XL']);
    expect(product.sizeLabel, 'XXS / M / L / XL');
    expect(product.equivalentSizeLabel, '34 / 38 / 42 / 44');
  });

  test('equivalent sizes follow the garment pair, not their own order', () {
    final product = Product.fromMap('p1', {
      'id': 'p1',
      'name': 'Remera',
      'sku': 'RM-1',
      'category': 'remeras',
      'brand': 'Test',
      'price': 10000,
      'images': <String>[],
      'equivalentSizes': {'S': '40', 'M': '36', 'L': '38'},
      'variants': [
        {'size': 'L', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 2},
        {'size': 'S', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 1},
        {'size': 'M', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 4},
      ],
      'status': 'activo',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(product.sizeLabel, 'S / M / L');
    expect(product.equivalentSizeLabel, '40 / 36 / 38');
  });

  test('numeric garment sizes sort ascending', () {
    final product = Product.fromMap('p1', {
      'id': 'p1',
      'name': 'Zapatilla',
      'sku': 'ZP-1',
      'category': 'zapatillas',
      'brand': 'Test',
      'price': 10000,
      'images': <String>[],
      'equivalentSizes': {'42': '10', '36': '6', '38': '8'},
      'variants': [
        {'size': '42', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 2},
        {'size': '36', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 1},
        {'size': '38', 'color': 'Negro', 'colorHex': '#1E1E1E', 'stock': 4},
      ],
      'status': 'activo',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(product.sizes, ['36', '38', '42']);
    expect(product.equivalentSizeLabel, '6 / 8 / 10');
  });

  test('garment sizes are common distinct values', () {
    expect(ApparelSizes.all.length, greaterThanOrEqualTo(12));
    expect(ApparelSizes.all.toSet().length, ApparelSizes.all.length);
    expect(
      ApparelSizes.all,
      containsAll(['XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', 'Único']),
    );
    expect(ApparelSizes.all.take(6).toList(), [
      'XXS',
      'XS',
      'S',
      'M',
      'L',
      'XL',
    ]);
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

  test('Product.fromMap reads an assigned lot id', () {
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
      'lotId': 'l1',
      'createdAt': stamp.toIso8601String(),
      'updatedAt': stamp.toIso8601String(),
      'deletedAt': null,
    });
    expect(product.lotId, 'l1');
    expect(product.hasLot, isTrue);
    expect(product.toMap()['lotId'], 'l1');
  });
}
