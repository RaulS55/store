import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/catalog_guest_store.dart';
import 'package:store_app/data/local/catalog_cart_cache.dart';
import 'package:store_app/data/order_share.dart';
import 'package:store_app/data/product_access.dart';
import 'package:store_app/data/session_exception.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/models/filters.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/models/record_source.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_company_access.dart';
import 'fakes/fake_customer_access.dart';
import 'fakes/fake_order_access.dart';
import 'fakes/fake_product_access.dart';

Company _company({String id = 'co1', String? phone = '+54 9 11 4555-0101'}) {
  return Company(
    id: id,
    name: 'Moda Stock',
    ownerId: 'u1',
    createdAt: DateTime.utc(2026, 9, 11),
    phone: phone,
  );
}

Future<CatalogGuestStore> _store({
  required FakeCompanyAccess companies,
  required FakeProductAccess products,
  required FakeCustomerAccess customers,
  required FakeOrderAccess orders,
  CatalogCartCache? cart,
  String companyId = 'co1',
}) async {
  final store = CatalogGuestStore(
    companyId: companyId,
    companies: companies,
    products: products,
    customers: customers,
    orders: orders,
    cart: cart,
  );
  await store.ready;
  return store;
}

void main() {
  test(
    'guest catalog shows active products and keeps one cart per company',
    () async {
      final companies = FakeCompanyAccess()
        ..companies['co1'] = _company()
        ..companies['co2'] = _company(id: 'co2', phone: '+54 9 11 4000-0000');
      final products = FakeProductAccess();
      await products.saveProduct('co1', testProduct());
      await products.saveProduct(
        'co1',
        testProduct(
          id: 'p-off',
          name: 'Inactiva',
          stock: 4,
        ).copyWith(status: ProductStatus.inactivo),
      );
      await products.saveProduct(
        'co2',
        testProduct(id: 'p-co2', name: 'Jean co2'),
      );
      final customers = FakeCustomerAccess();
      final orders = FakeOrderAccess();
      final cart = MemoryCatalogCartCache();

      final storeA = await _store(
        companies: companies,
        products: products,
        customers: customers,
        orders: orders,
        cart: cart,
      );
      addTearDown(storeA.dispose);
      final storeB = await _store(
        companies: companies,
        products: products,
        customers: customers,
        orders: orders,
        cart: cart,
        companyId: 'co2',
      );
      addTearDown(storeB.dispose);

      expect(storeA.visibleProducts.map((p) => p.id), ['p-test']);
      expect(storeB.visibleProducts.map((p) => p.id), ['p-co2']);

      storeA.addToCart(
        storeA.visibleProducts.first,
        storeA.visibleProducts.first.variants.first,
      );
      storeB.addToCart(
        storeB.visibleProducts.first,
        storeB.visibleProducts.first.variants.first,
        quantity: 2,
      );

      expect(storeA.cartCount, 1);
      expect(storeB.cartCount, 2);
      expect(storeA.cartLines.single.product.id, 'p-test');
      expect(storeB.cartLines.single.product.id, 'p-co2');
    },
  );

  test(
    'submit creates a catalog order, WhatsApp to the business, then a fresh cart',
    () async {
      final companies = FakeCompanyAccess()..companies['co1'] = _company();
      final products = FakeProductAccess();
      await products.saveProduct('co1', testProduct());
      final customers = FakeCustomerAccess();
      final orders = FakeOrderAccess();
      final store = await _store(
        companies: companies,
        products: products,
        customers: customers,
        orders: orders,
      );
      addTearDown(store.dispose);

      final product = store.visibleProducts.single;
      store.addToCart(product, product.variants.first, quantity: 2);

      await expectLater(
        store.submit(name: 'J'),
        throwsA(isA<SessionException>()),
      );

      final first = await store.submit(name: '  Juan Pérez  ');
      expect(store.cartCount, 0);
      expect(first.order.isCatalog, isTrue);
      expect(first.order.ivaEnabled, isFalse);
      expect(first.order.customer.name, 'Juan Pérez');
      expect(first.order.customer.isCatalog, isTrue);
      expect(first.order.customer.phone, isNull);
      expect(first.order.orderNumber, startsWith('WEB-'));
      expect(first.missingPhone, isFalse);
      expect(first.whatsappUri, isNotNull);
      expect(first.whatsappUri!.path, contains('5491145550101'));
      expect(
        OrderShare.catalogMessage(first.order),
        contains('Hola, soy Juan Pérez.'),
      );
      expect(OrderShare.catalogMessage(first.order), isNot(contains('Mónica')));
      expect(
        customers.customers['co1']!.values.single.source,
        RecordSource.catalog,
      );
      expect(orders.orders['co1']!.values.single.id, first.order.id);

      store.addToCart(product, product.variants.first);
      final second = await store.submit(name: 'Ana');
      expect(orders.orders['co1']!.length, 2);
      expect(second.order.id, isNot(first.order.id));
      expect(customers.customers['co1']!.length, 2);
    },
  );

  test('submit without a company phone still saves the order', () async {
    final companies = FakeCompanyAccess()
      ..companies['co1'] = _company(phone: null);
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final customers = FakeCustomerAccess();
    final orders = FakeOrderAccess();
    final store = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
    );
    addTearDown(store.dispose);
    final product = store.visibleProducts.single;
    store.addToCart(product, product.variants.first);
    final result = await store.submit(name: 'Luis');
    expect(result.missingPhone, isTrue);
    expect(result.whatsappUri, isNull);
    expect(orders.orders['co1'], isNotEmpty);
  });

  test('catalog stops loading if company and products never arrive', () async {
    final products = _HangingProductAccess();
    final store = CatalogGuestStore(
      companyId: 'co1',
      companies: _HangingCompanyAccess(),
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
      loadTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(() {
      store.dispose();
      products.close();
    });
    await store.ready;
    expect(store.isLoading, isFalse);
    expect(store.notFound, isTrue);
  });

  test('catalog stops loading if the company lookup throws', () async {
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final store = CatalogGuestStore(
      companyId: 'co1',
      companies: _ThrowingCompanyAccess(),
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
      loadTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(store.dispose);
    await store.ready;
    expect(store.isLoading, isFalse);
    expect(store.notFound, isTrue);
  });

  test(
    'guest catalog applies the same category and audience filters',
    () async {
      final companies = FakeCompanyAccess()..companies['co1'] = _company();
      final products = FakeProductAccess();
      await products.saveProduct(
        'co1',
        testProduct(
          id: 'p-m',
          name: 'Remera mujer',
          audience: ApparelAudience.mujer,
        ),
      );
      await products.saveProduct(
        'co1',
        testProduct(
          id: 'p-h',
          name: 'Jean hombre',
          sku: 'TST-0002',
          category: ApparelCategory.jeans,
          audience: ApparelAudience.hombre,
        ),
      );
      final store = await _store(
        companies: companies,
        products: products,
        customers: FakeCustomerAccess(),
        orders: FakeOrderAccess(),
      );
      addTearDown(store.dispose);

      expect(store.visibleProducts.map((p) => p.id).toSet(), {'p-h', 'p-m'});

      store.selectChipCategory(ApparelCategory.remeras);
      expect(store.visibleProducts.map((p) => p.id), ['p-m']);

      store.selectChipCategory(null);
      store.selectChipAudience(ApparelAudience.hombre);
      expect(store.visibleProducts.map((p) => p.id), ['p-h']);

      store.clearFilters();
      store.applyFilters(const ProductFilters(sizes: {'M'}));
      expect(store.visibleProducts.map((p) => p.id).toSet(), {'p-m', 'p-h'});
    },
  );
}

class _HangingCompanyAccess extends FakeCompanyAccess {
  final _pending = Completer<Company?>();

  @override
  Future<Company?> getCompany(String companyId) => _pending.future;
}

class _ThrowingCompanyAccess extends FakeCompanyAccess {
  @override
  Future<Company?> getCompany(String companyId) {
    throw Exception('unavailable');
  }
}

class _HangingProductAccess implements ProductAccess {
  final _controller = StreamController<List<Product>>.broadcast();

  @override
  String nextProductId(String companyId) => 'p-hang';

  @override
  Stream<List<Product>> watchProducts(String companyId) => _controller.stream;

  @override
  Future<void> saveProduct(String companyId, Product product) async {}

  void close() {
    _controller.close();
  }
}
