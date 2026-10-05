import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/filters.dart';

import 'fakes/catalog_harness.dart';

void main() {
  test('stock hides out of stock garments by default', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p-in', name: 'Remera lisa'));
    await store.upsertProduct(
      testProduct(id: 'p-out', name: 'Remera vieja', sku: 'OUT-0001', stock: 0),
    );

    expect(store.filteredProducts.map((p) => p.id), ['p-in']);
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

  test('stock search by brand keeps out of stock hidden', () async {
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
    expect(store.filteredProducts.map((p) => p.id), ['p-in']);
  });

  test('stock filter lists only out of stock garments', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p-in', name: 'Remera lisa'));
    await store.upsertProduct(
      testProduct(id: 'p-out', name: 'Remera vieja', sku: 'OUT-0001', stock: 0),
    );

    store.applyFilters(const ProductFilters(onlyOutOfStock: true));
    expect(store.filteredProducts.map((p) => p.id), ['p-out']);
  });
}
