import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/features/stock/product_table.dart';
import 'package:store_app/models/filters.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/theme/app_theme.dart';
import 'package:store_app/theme/tokens.dart';
import 'package:store_app/widgets/product_card.dart';

import 'fakes/catalog_harness.dart';

void main() {
  test('stock lists out of stock garments last', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p-in', name: 'Remera lisa'));
    await store.upsertProduct(
      testProduct(id: 'p-out', name: 'Remera vieja', sku: 'OUT-0001', stock: 0),
    );

    expect(store.filteredProducts.map((p) => p.id), ['p-in', 'p-out']);
  });

  test('stock search by name shows out of stock last', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p-in', name: 'Remera lisa'));
    await store.upsertProduct(
      testProduct(id: 'p-out', name: 'Remera vieja', sku: 'OUT-0001', stock: 0),
    );

    store.setSearch('remera');
    expect(store.filteredProducts.map((p) => p.id), ['p-in', 'p-out']);
  });

  test('stock search by code shows out of stock garments', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p-in', name: 'Jean oscuro'));
    await store.upsertProduct(
      testProduct(id: 'p-out', name: 'Remera vieja', sku: 'OUT-0001', stock: 0),
    );

    store.setSearch('out-0001');
    expect(store.filteredProducts.map((p) => p.id), ['p-out']);
  });

  test('stock search matches a size only when it is written exactly', () async {
    final store = AppStore();
    await store.upsertProduct(
      _sizedProduct('p-xxl', {'XXL': 2}, name: 'Campera norte', sku: 'A-100'),
    );
    await store.upsertProduct(
      _sizedProduct('p-xl', {'XL': 2}, name: 'Campera sur', sku: 'A-200'),
    );
    await store.upsertProduct(
      _sizedProduct('p-l', {'L': 2}, name: 'Campera este', sku: 'A-300'),
    );

    store.setSearch('xxl');
    expect(store.filteredProducts.map((p) => p.id), ['p-xxl']);

    store.setSearch('XXL');
    expect(store.filteredProducts.map((p) => p.id), ['p-xxl']);

    store.setSearch('xxle');
    expect(store.filteredProducts, isEmpty);

    store.setSearch('XL');
    expect(store.filteredProducts.map((p) => p.id), ['p-xl']);

    store.setSearch('L');
    expect(store.filteredProducts.map((p) => p.id), ['p-l']);
  });

  test('searching a size acts like selecting that size filter', () async {
    final store = AppStore();
    await store.upsertProduct(
      _sizedProduct('p-s', {'S': 4, 'M': 1}, name: 'Solero', sku: 'B-1'),
    );
    await store.upsertProduct(
      _sizedProduct(
        'p-gap',
        {'S': 0, 'M': 3, 'L': 2},
        name: 'Camisa',
        sku: 'B-2',
      ),
    );
    await store.upsertProduct(
      _sizedProduct('p-other', {'M': 5}, name: 'Sueter', sku: 'B-3'),
    );

    store.setSearch('s');
    final bySearch = store.filteredProducts.map((p) => p.id).toList();
    expect(bySearch, ['p-s', 'p-gap']);
    expect(store.focusedSizes, {'S'});

    store.setSearch('');
    store.applyFilters(const ProductFilters(sizes: {'S'}));
    expect(store.filteredProducts.map((p) => p.id).toList(), bySearch);
    expect(store.focusedSizes, {'S'});
  });

  test('stock search by brand keeps out of stock last', () async {
    final store = AppStore();
    await store.upsertProduct(
      testProduct(id: 'p-in', name: 'Jean oscuro', brand: 'Urban'),
    );
    await store.upsertProduct(
      testProduct(
        id: 'p-out',
        name: 'Remera vieja',
        sku: 'OUT-0001',
        brand: 'Urban',
        stock: 0,
      ),
    );

    store.setSearch('urban');
    expect(store.filteredProducts.map((p) => p.id), ['p-in', 'p-out']);
  });

  test('stock category filter keeps matching out of stock last', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p-in', name: 'Remera lisa'));
    await store.upsertProduct(
      testProduct(id: 'p-out', name: 'Remera vieja', sku: 'OUT-0001', stock: 0),
    );
    await store.upsertProduct(
      testProduct(
        id: 'p-jean',
        name: 'Jean vacio',
        sku: 'JN-0001',
        category: ApparelCategory.jeans,
        stock: 0,
      ),
    );

    store.selectChipCategory(ApparelCategory.remeras);
    expect(store.filteredProducts.map((p) => p.id), ['p-in', 'p-out']);
  });

  test('stock brand filter keeps matching out of stock last', () async {
    final store = AppStore();
    await store.upsertProduct(
      testProduct(id: 'p-in', name: 'Jean oscuro', brand: 'Urban'),
    );
    await store.upsertProduct(
      testProduct(
        id: 'p-out',
        name: 'Remera vieja',
        sku: 'OUT-0001',
        brand: 'Urban',
        stock: 0,
      ),
    );
    await store.upsertProduct(
      testProduct(
        id: 'p-other',
        name: 'Buzo vacio',
        sku: 'BZ-0001',
        brand: 'Otra',
        stock: 0,
      ),
    );

    store.applyFilters(const ProductFilters(brands: {'Urban'}));
    expect(store.filteredProducts.map((p) => p.id), ['p-in', 'p-out']);
  });

  test('stock sort still leaves out of stock last', () async {
    final store = AppStore();
    await store.upsertProduct(
      testProduct(id: 'p-high', name: 'Zeta', stock: 20),
    );
    await store.upsertProduct(
      testProduct(id: 'p-out', name: 'Alfa', sku: 'OUT-0001', stock: 0),
    );

    store.setSort(StockSort.name);
    expect(store.filteredProducts.map((p) => p.id), ['p-high', 'p-out']);

    store.setSort(StockSort.stockAsc);
    expect(store.filteredProducts.map((p) => p.id), ['p-high', 'p-out']);
  });

  test('stock low stock filter keeps out of stock last', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p-ok', name: 'Remera lisa'));
    await store.upsertProduct(
      testProduct(id: 'p-low', name: 'Remera poca', sku: 'LOW-0001', stock: 2),
    );
    await store.upsertProduct(
      testProduct(id: 'p-out', name: 'Remera vieja', sku: 'OUT-0001', stock: 0),
    );

    store.applyFilters(const ProductFilters(onlyLowStock: true));
    expect(store.filteredProducts.map((p) => p.id), ['p-low', 'p-out']);
  });

  test('stock low stock filter can also include out of stock', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p-ok', name: 'Remera lisa'));
    await store.upsertProduct(
      testProduct(id: 'p-low', name: 'Remera poca', sku: 'LOW-0001', stock: 2),
    );
    await store.upsertProduct(
      testProduct(id: 'p-out', name: 'Remera vieja', sku: 'OUT-0001', stock: 0),
    );

    store.applyFilters(
      const ProductFilters(onlyLowStock: true, includeOutOfStock: true),
    );
    expect(store.filteredProducts.map((p) => p.id), ['p-low', 'p-out']);
  });

  testWidgets('out of stock card shows a red indicator', (tester) async {
    final product = testProduct(name: 'Remera vieja', stock: 0);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 360,
            child: ProductCard(product: product, onTap: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Sin stock'), findsWidgets);
    final ink = tester.widget<Ink>(find.byType(Ink));
    final border = (ink.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppColors.stockLow);
  });

  testWidgets('stock table marks out of stock rows in red', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AppStore(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProductTable(
              products: [testProduct(name: 'Remera vieja', stock: 0)],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sin stock'), findsWidgets);
    expect(find.text('Bajo stock'), findsNothing);
    expect(find.text('Disponible'), findsNothing);
    final label = tester.widget<Text>(find.text('Sin stock').first);
    expect(label.style?.color, AppColors.stockLow);
  });

  test(
    'size filter keeps garments whose selected size is gone at the end',
    () async {
      final store = AppStore();
      await store.upsertProduct(_sizedProduct('p-s', {'S': 4, 'M': 2}));
      await store.upsertProduct(
        _sizedProduct('p-gap', {'S': 0, 'M': 3, 'L': 2}),
      );
      await store.upsertProduct(_sizedProduct('p-other', {'M': 5}));

      store.applyFilters(const ProductFilters(sizes: {'S'}));
      expect(store.filteredProducts.map((p) => p.id), ['p-s', 'p-gap']);

      store.setSort(StockSort.name);
      expect(store.filteredProducts.map((p) => p.id), ['p-s', 'p-gap']);
    },
  );

  test(
    'size filter stays in place when another selected size still has stock',
    () async {
      final store = AppStore();
      await store.upsertProduct(_sizedProduct('p-both', {'S': 2, 'M': 2}));
      await store.upsertProduct(
        _sizedProduct('p-only-m', {'S': 0, 'M': 4, 'L': 1}),
      );
      await store.upsertProduct(
        _sizedProduct('p-none', {'S': 0, 'M': 0, 'L': 6}),
      );

      store.applyFilters(const ProductFilters(sizes: {'S', 'M'}));
      store.setSort(StockSort.name);
      expect(store.filteredProducts.map((p) => p.id), [
        'p-both',
        'p-only-m',
        'p-none',
      ]);
    },
  );

  testWidgets('card marks the filtered size that is out of stock', (
    tester,
  ) async {
    final product = _sizedProduct('p-gap', {'S': 0, 'M': 3, 'L': 2});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 360,
            child: ProductCard(
              product: product,
              filteredSizes: const {'S'},
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sin stock en S'), findsWidgets);
    final ink = tester.widget<Ink>(find.byType(Ink));
    final border = (ink.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppColors.stockGap);
    expect(
      tester
          .widgetList<Text>(find.text('Sin stock en S'))
          .any((text) => text.style?.color == AppColors.stockGap),
      isTrue,
    );
  });

  testWidgets('stock table marks a filtered size that is out of stock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AppStore(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProductTable(
              products: [
                _sizedProduct('p-gap', {'S': 0, 'M': 3}),
              ],
              filteredSizes: const {'S'},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sin stock en S'), findsWidgets);
    final label = tester.widget<Text>(find.text('Sin stock en S').first);
    expect(label.style?.color, AppColors.stockGap);
  });
}

Product _sizedProduct(
  String id,
  Map<String, int> stockBySize, {
  String? name,
  String? sku,
}) {
  final stamp = DateTime.utc(2026, 9, 11);
  return Product(
    id: id,
    name: name ?? id,
    sku: sku ?? id,
    category: ApparelCategory.remeras,
    brand: 'Test',
    price: 1000,
    images: const [],
    variants: [
      for (final entry in stockBySize.entries)
        ProductVariant(
          size: entry.key,
          color: 'Negro',
          colorHex: '#1E1E1E',
          stock: entry.value,
        ),
    ],
    createdAt: stamp,
    updatedAt: stamp,
  );
}
