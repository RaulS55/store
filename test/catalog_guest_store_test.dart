import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/catalog_request_access.dart';
import 'package:store_app/data/catalog_guest_store.dart';
import 'package:store_app/data/local/catalog_cart_cache.dart';
import 'package:store_app/data/local/hive_catalog_cache.dart';
import 'package:store_app/data/order_share.dart';
import 'package:store_app/data/product_access.dart';
import 'package:store_app/data/product_filter_host.dart';
import 'package:store_app/data/session_exception.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/models/customer.dart';
import 'package:store_app/models/filters.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/models/record_source.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_catalog_request_access.dart';
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
  CatalogRequestAccess? requests,
  CatalogCartCache? cart,
  String companyId = 'co1',
}) async {
  final store = CatalogGuestStore(
    companyId: companyId,
    companies: companies,
    products: products,
    customers: customers,
    orders: orders,
    requests: requests ?? FakeCatalogRequestAccess(),
    cart: cart,
  );
  await store.ready;
  return store;
}

Future<void> _flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<DraftOrder> _approve(
  CatalogGuestStore guest, {
  required FakeCustomerAccess customers,
  required FakeOrderAccess orders,
  required FakeCatalogRequestAccess requests,
}) async {
  final business = AppStore(
    customers: customers,
    orderAccess: orders,
    catalogRequests: requests,
  );
  addTearDown(business.dispose);
  business.bindCompany('co1');
  final order = await business.approveCatalogRequest(guest.pendingRequest!.id);
  await _flush();
  return order;
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
    'submit asks for approval and the business loads it as an order',
    () async {
      final companies = FakeCompanyAccess()..companies['co1'] = _company();
      final products = FakeProductAccess();
      await products.saveProduct('co1', testProduct());
      final customers = FakeCustomerAccess();
      final orders = FakeOrderAccess();
      final requests = FakeCatalogRequestAccess();
      final store = await _store(
        companies: companies,
        products: products,
        customers: customers,
        orders: orders,
        requests: requests,
      );
      addTearDown(store.dispose);

      final product = store.visibleProducts.single;
      store.addToCart(product, product.variants.first, quantity: 2);

      await expectLater(
        store.submit(name: 'J', phone: '+54 9 11 5555-1234'),
        throwsA(isA<SessionException>()),
      );
      await expectLater(
        store.submit(name: 'Juan', phone: '123'),
        throwsA(isA<SessionException>()),
      );
      expect(requests.requests['co1'], isNull);

      final first = await store.submit(
        name: '  Juan Pérez  ',
        phone: '11 5555-1234',
      );
      expect(store.cartCount, 2);
      expect(store.pendingCartLines, isEmpty);
      expect(store.awaitingCartLines.single.quantity, 2);
      expect(store.requestedCartLines, isEmpty);
      expect(store.openOrder, isNull);
      expect(store.pendingRequest?.id, first.request.id);
      expect(first.updated, isFalse);
      expect(first.request.isPending, isTrue);
      expect(first.request.isAddition, isFalse);
      expect(first.order.isCatalog, isTrue);
      expect(first.order.ivaEnabled, isFalse);
      expect(first.order.customer.name, 'Juan Pérez');
      expect(first.order.customer.isCatalog, isTrue);
      expect(first.order.customer.phone, '+54 9 11 5555-1234');
      expect(first.request.customerPhone, '+54 9 11 5555-1234');
      expect(first.order.orderNumber, isEmpty);
      expect(first.missingPhone, isFalse);
      expect(first.whatsappUri, isNotNull);
      expect(first.whatsappUri!.path, contains('5491145550101'));
      expect(
        OrderShare.catalogMessage(first.order, awaitingApproval: true),
        contains('Hola, soy Juan Pérez.'),
      );
      expect(
        OrderShare.catalogMessage(first.order, awaitingApproval: true),
        contains('Mi teléfono es +54 9 11 5555-1234.'),
      );
      expect(
        OrderShare.catalogMessage(first.order, awaitingApproval: true),
        contains('Quiero este pedido:'),
      );
      expect(
        OrderShare.catalogMessage(first.order, awaitingApproval: true),
        contains('TST-0001-M-NEGRO - Remera test'),
      );
      expect(
        OrderShare.catalogMessage(first.order, awaitingApproval: true),
        isNot(contains('WEB-')),
      );
      expect(
        OrderShare.catalogMessage(first.order, awaitingApproval: true),
        isNot(contains('Mónica')),
      );
      expect(orders.orders['co1'], isNull);
      expect(customers.customers['co1'], isNull);

      final key = store.awaitingCartLines.single.lineKey;
      store.setLineQty(key, 1);
      store.removeLine(key);
      expect(store.awaitingCartLines.single.quantity, 2);
      expect(store.pendingCartLines, isEmpty);

      store.addToCart(product, product.variants.first);
      expect(store.pendingCartLines.single.quantity, 1);
      final second = await store.submit(name: 'Ana', phone: '11 4444-5678');
      expect(second.updated, isTrue);
      expect(second.request.id, first.request.id);
      expect(second.request.customerName, 'Ana');
      expect(second.request.customerPhone, '+54 9 11 4444-5678');
      expect(requests.requests['co1']!.length, 1);
      expect(requests.requests['co1']!.values.single.lines.single.quantity, 3);
      expect(orders.orders['co1'], isNull);
      expect(store.pendingCartLines, isEmpty);
      expect(store.awaitingCartLines.single.quantity, 3);
      expect(
        OrderShare.catalogMessage(
          second.order,
          updated: true,
          awaitingApproval: true,
        ),
        contains('Actualicé la solicitud:'),
      );
      expect(
        OrderShare.catalogMessage(
          second.order,
          updated: true,
          awaitingApproval: true,
          addedLines: [
            OrderLine(
              product: product,
              variant: product.variants.first,
              quantity: 1,
            ),
          ],
        ),
        contains('1×'),
      );

      final order = await _approve(
        store,
        customers: customers,
        orders: orders,
        requests: requests,
      );
      expect(order.orderNumber, startsWith('WEB-'));
      expect(order.isCatalog, isTrue);
      expect(order.ivaEnabled, isFalse);
      expect(order.customer.name, 'Ana (Catalogo)');
      expect(order.customer.isCatalog, isTrue);
      expect(order.customer.phone, '+54 9 11 4444-5678');
      expect(store.openOrder?.customerPhone, '+54 9 11 4444-5678');
      expect(
        customers.customers['co1']!.values.single.source,
        RecordSource.catalog,
      );
      expect(orders.orders['co1']!.values.single.id, order.id);
      expect(orders.orders['co1']!.values.single.lines.single.quantity, 3);
      expect(store.openOrder?.orderId, order.id);
      expect(store.requestedCartLines.single.quantity, 3);
      expect(store.awaitingCartLines, isEmpty);
      expect(store.pendingRequest, isNull);

      final reloaded = AppStore(
        customers: customers,
        orderAccess: orders,
        catalogRequests: requests,
      );
      addTearDown(reloaded.dispose);
      reloaded.bindCompany('co1');
      await _flush();
      expect(reloaded.pendingCatalogRequests, isEmpty);
      expect(reloaded.catalogRequests.single.isApproved, isTrue);
    },
  );

  test('a later submit waits for approval before updating the order', () async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final customers = FakeCustomerAccess();
    final orders = FakeOrderAccess();
    final requests = FakeCatalogRequestAccess();
    final cart = MemoryCatalogCartCache();
    final firstStore = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
      cart: cart,
    );
    addTearDown(firstStore.dispose);
    final product = firstStore.visibleProducts.single;
    firstStore.addToCart(product, product.variants.first);
    await firstStore.submit(name: 'Juan', phone: '+54 9 11 5555-1234');
    final created = await _approve(
      firstStore,
      customers: customers,
      orders: orders,
      requests: requests,
    );

    final secondStore = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
      cart: cart,
    );
    addTearDown(secondStore.dispose);
    expect(secondStore.openOrder?.orderNumber, created.orderNumber);
    expect(secondStore.openOrder?.customerPhone, '+54 9 11 5555-1234');
    expect(secondStore.cartCount, 1);
    expect(secondStore.pendingCartLines, isEmpty);
    secondStore.addToCart(
      secondStore.visibleProducts.single,
      secondStore.visibleProducts.single.variants.first,
    );
    final second = await secondStore.submit(
      name: 'Juan',
      phone: '+54 9 11 5555-1234',
    );
    expect(second.updated, isTrue);
    expect(second.request.isAddition, isTrue);
    expect(second.request.targetOrderId, created.id);
    expect(orders.orders['co1']!.length, 1);
    expect(orders.orders['co1']!.values.single.lines.single.quantity, 1);
    await _approve(
      secondStore,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    expect(orders.orders['co1']!.values.single.lines.single.quantity, 2);
    expect(
      orders.orders['co1']!.values.single.customer.name,
      'Juan (Catalogo)',
    );
  });

  test('same catalog name and phone stay one customer', () async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final customers = FakeCustomerAccess();
    final orders = FakeOrderAccess();
    final requests = FakeCatalogRequestAccess();
    final stamp = DateTime.utc(2026, 9, 11);
    await customers.saveCustomer(
      'co1',
      Customer(
        id: 'c-staff',
        name: 'Raul',
        phone: '11 5555-1234',
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
    final business = AppStore(
      products: products,
      customers: customers,
      orderAccess: orders,
      catalogRequests: requests,
    );
    addTearDown(business.dispose);
    business.bindCompany('co1');
    await _flush();

    final firstGuest = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(firstGuest.dispose);
    final product = firstGuest.visibleProducts.single;
    firstGuest.addToCart(product, product.variants.first);
    await firstGuest.submit(name: 'raul', phone: '+54 9 11 5555-1234');
    final first = await business.approveCatalogRequest(
      firstGuest.pendingRequest!.id,
    );
    expect(first.customer.id, 'c-staff');
    expect(first.customer.name, 'Raul (Catalogo)');
    expect(customers.customers['co1']!.length, 1);

    final whileOpen = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(whileOpen.dispose);
    whileOpen.addToCart(product, product.variants.first, quantity: 2);
    await whileOpen.submit(name: 'Raul', phone: '11 5555-1234');
    final merged = await business.approveCatalogRequest(
      whileOpen.pendingRequest!.id,
    );
    expect(merged.id, first.id);
    expect(merged.customer.id, 'c-staff');
    expect(merged.lines.single.quantity, 3);
    expect(customers.customers['co1']!.length, 1);

    expect(business.closeOrder(first.id), isTrue);

    final secondGuest = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(secondGuest.dispose);
    secondGuest.addToCart(
      secondGuest.visibleProducts.single,
      secondGuest.visibleProducts.single.variants.first,
    );
    await secondGuest.submit(name: 'Raul (Catalogo)', phone: '1155551234');
    final second = await business.approveCatalogRequest(
      secondGuest.pendingRequest!.id,
    );
    expect(second.id, isNot(first.id));
    expect(second.customer.id, 'c-staff');
    expect(second.customer.name, 'Raul (Catalogo)');
    expect(customers.customers['co1']!.length, 1);

    final otherPhone = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(otherPhone.dispose);
    otherPhone.addToCart(
      otherPhone.visibleProducts.single,
      otherPhone.visibleProducts.single.variants.first,
    );
    await otherPhone.submit(name: 'Raul', phone: '11 4444-5678');
    final third = await business.approveCatalogRequest(
      otherPhone.pendingRequest!.id,
    );
    expect(third.customer.id, isNot('c-staff'));
    expect(third.customer.name, 'Raul (Catalogo)');
    expect(customers.customers['co1']!.length, 2);
  });

  test('closing the order from the business clears the client cart', () async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final customers = FakeCustomerAccess();
    final orders = FakeOrderAccess();
    final requests = FakeCatalogRequestAccess();
    final store = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(store.dispose);
    final product = store.visibleProducts.single;
    store.addToCart(product, product.variants.first);
    await store.submit(name: 'Juan', phone: '+54 9 11 5555-1234');
    await _approve(
      store,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    store.addToCart(product, product.variants.first);
    expect(store.pendingCartLines, isNotEmpty);

    final orderId = store.openOrder!.orderId;
    orders.orders['co1']![orderId]!.status = OrderStatus.cerrado;
    orders.orders['co1']![orderId]!.closedAt = DateTime.utc(2026, 9, 26);
    orders.emitOrder('co1', orderId);
    await Future<void>.delayed(Duration.zero);

    expect(store.openOrder, isNull);
    expect(store.cartCount, 0);
    expect(store.pendingCartLines, isEmpty);
    expect(store.requestedCartLines, isEmpty);
    expect(orders.orders['co1']!.length, 1);
  });

  test(
    'submit does not open a new order if the previous one was closed',
    () async {
      final companies = FakeCompanyAccess()..companies['co1'] = _company();
      final products = FakeProductAccess();
      await products.saveProduct('co1', testProduct());
      final customers = FakeCustomerAccess();
      final orders = FakeOrderAccess();
      final requests = FakeCatalogRequestAccess();
      final store = await _store(
        companies: companies,
        products: products,
        customers: customers,
        orders: orders,
        requests: requests,
      );
      addTearDown(store.dispose);
      final product = store.visibleProducts.single;
      store.addToCart(product, product.variants.first);
      await store.submit(name: 'Juan', phone: '+54 9 11 5555-1234');
      await _approve(
        store,
        customers: customers,
        orders: orders,
        requests: requests,
      );
      store.addToCart(product, product.variants.first);
      final orderId = store.openOrder!.orderId;
      orders.orders['co1']![orderId]!.status = OrderStatus.cerrado;
      orders.orders['co1']![orderId]!.closedAt = DateTime.utc(2026, 9, 26);

      await expectLater(
        store.submit(name: 'Juan', phone: '+54 9 11 5555-1234'),
        throwsA(
          isA<SessionException>().having(
            (error) => error.message,
            'message',
            contains('cerró el pedido'),
          ),
        ),
      );
      expect(store.openOrder, isNull);
      expect(store.cartCount, 0);
      expect(orders.orders['co1']!.length, 1);
    },
  );

  test('removing a line in the business drops it from Ya solicitado', () async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    await products.saveProduct(
      'co1',
      testProduct(id: 'p-jean', name: 'Jean test', sku: 'TST-0002'),
    );
    final customers = FakeCustomerAccess();
    final orders = FakeOrderAccess();
    final requests = FakeCatalogRequestAccess();
    final store = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(store.dispose);
    final shirt = store.productById('p-test')!;
    final jean = store.productById('p-jean')!;
    store.addToCart(shirt, shirt.variants.first);
    store.addToCart(jean, jean.variants.first);
    await store.submit(name: 'Juan', phone: '+54 9 11 5555-1234');
    final created = await _approve(
      store,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    expect(store.requestedCartLines, hasLength(2));

    final remote = orders.orders['co1']![created.id]!;
    remote.lines.removeWhere((line) => line.product.id == 'p-jean');
    orders.emitOrder('co1', created.id);
    await Future<void>.delayed(Duration.zero);

    expect(store.requestedCartLines, hasLength(1));
    expect(store.requestedCartLines.single.product.id, 'p-test');
    expect(store.openOrder?.orderId, created.id);
  });

  test('submit without a company phone still saves the request', () async {
    final companies = FakeCompanyAccess()
      ..companies['co1'] = _company(phone: null);
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final customers = FakeCustomerAccess();
    final orders = FakeOrderAccess();
    final requests = FakeCatalogRequestAccess();
    final store = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(store.dispose);
    final product = store.visibleProducts.single;
    store.addToCart(product, product.variants.first);
    final result = await store.submit(
      name: 'Luis',
      phone: '+54 9 11 5555-1234',
    );
    expect(result.missingPhone, isTrue);
    expect(result.whatsappUri, isNull);
    expect(requests.requests['co1'], isNotEmpty);
    expect(orders.orders['co1'], isNull);
  });

  test('rejecting the request returns the garments to the cart', () async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final customers = FakeCustomerAccess();
    final orders = FakeOrderAccess();
    final requests = FakeCatalogRequestAccess();
    final store = await _store(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(store.dispose);
    final product = store.visibleProducts.single;
    store.addToCart(product, product.variants.first, quantity: 2);
    await store.submit(name: 'Juan', phone: '+54 9 11 5555-1234');
    expect(store.awaitingCartLines.single.quantity, 2);

    final business = AppStore(
      customers: customers,
      orderAccess: orders,
      catalogRequests: requests,
    );
    addTearDown(business.dispose);
    business.bindCompany('co1');
    await business.rejectCatalogRequest(store.pendingRequest!.id);
    await _flush();

    expect(store.pendingRequest, isNull);
    expect(store.awaitingCartLines, isEmpty);
    expect(store.pendingCartLines.single.quantity, 2);
    expect(orders.orders['co1'], isNull);
    expect(requests.requests['co1']!.values.single.isRejected, isTrue);

    final reloaded = AppStore(
      customers: customers,
      orderAccess: orders,
      catalogRequests: requests,
    );
    addTearDown(reloaded.dispose);
    reloaded.bindCompany('co1');
    await _flush();
    expect(reloaded.pendingCatalogRequests, isEmpty);
    expect(reloaded.catalogRequests.single.isRejected, isTrue);
  });

  test(
    'cached company shows the catalog without waiting for the API',
    () async {
      final cache = await HiveCatalogCache.openInMemory();
      addTearDown(cache.close);
      await cache.saveCompany(_company());
      final products = FakeProductAccess();
      await products.saveProduct('co1', testProduct());
      final store = CatalogGuestStore(
        companyId: 'co1',
        companies: _HangingCompanyAccess(),
        products: products,
        customers: FakeCustomerAccess(),
        orders: FakeOrderAccess(),
        requests: FakeCatalogRequestAccess(),
        local: cache,
        loadTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(store.dispose);
      await store.ready;
      expect(store.isLoading, isFalse);
      expect(store.notFound, isFalse);
      expect(store.company?.name, 'Moda Stock');
      expect(store.visibleProducts.map((item) => item.id), ['p-test']);
    },
  );

  test('catalog stops loading if company and products never arrive', () async {
    final products = _HangingProductAccess();
    final store = CatalogGuestStore(
      companyId: 'co1',
      companies: _HangingCompanyAccess(),
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
      requests: FakeCatalogRequestAccess(),
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
      requests: FakeCatalogRequestAccess(),
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
        requests: FakeCatalogRequestAccess(),
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

  test('guest catalog filters only list categories with garments', () async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    await products.saveProduct(
      'co1',
      testProduct(
        id: 'p-jeans',
        name: 'Jean',
        sku: 'TST-0002',
        category: ApparelCategory.jeans,
      ),
    );
    await products.saveProduct(
      'co1',
      testProduct(
        id: 'p-out',
        name: 'Musculosa sin stock',
        sku: 'TST-0003',
        category: ApparelCategory.musculosas,
        stock: 0,
      ),
    );
    final store = await _store(
      companies: companies,
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
      requests: FakeCatalogRequestAccess(),
    );
    addTearDown(store.dispose);

    expect(store.visibleCategories, [
      ApparelCategory.remeras,
      ApparelCategory.jeans,
    ]);
    expect(
      store.visibleCategories,
      isNot(contains(ApparelCategory.musculosas)),
    );
  });

  test(
    'guest catalog lists categories and audiences with more garments first',
    () async {
      final companies = FakeCompanyAccess()..companies['co1'] = _company();
      final products = FakeProductAccess();
      await products.saveProduct('co1', testProduct(id: 'p-r1'));
      await products.saveProduct(
        'co1',
        testProduct(
          id: 'p-j1',
          sku: 'TST-0002',
          category: ApparelCategory.jeans,
        ),
      );
      await products.saveProduct(
        'co1',
        testProduct(
          id: 'p-j2',
          sku: 'TST-0003',
          category: ApparelCategory.jeans,
        ),
      );
      await products.saveProduct(
        'co1',
        testProduct(
          id: 'p-m1',
          sku: 'TST-0004',
          category: ApparelCategory.jeans,
          audience: ApparelAudience.mujer,
        ),
      );
      await products.saveProduct(
        'co1',
        testProduct(
          id: 'p-m2',
          sku: 'TST-0005',
          category: ApparelCategory.jeans,
          audience: ApparelAudience.mujer,
        ),
      );
      await products.saveProduct(
        'co1',
        testProduct(
          id: 'p-h1',
          sku: 'TST-0006',
          category: ApparelCategory.jeans,
          audience: ApparelAudience.hombre,
        ),
      );
      final store = await _store(
        companies: companies,
        products: products,
        customers: FakeCustomerAccess(),
        orders: FakeOrderAccess(),
        requests: FakeCatalogRequestAccess(),
      );
      addTearDown(store.dispose);

      expect(store.visibleCategories, [
        ApparelCategory.jeans,
        ApparelCategory.remeras,
      ]);
      expect(store.visibleAudiences, [
        ApparelAudience.mujer,
        ApparelAudience.hombre,
      ]);
    },
  );

  test('guest catalog hides audience when only one public is used', () async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct(
      'co1',
      testProduct(audience: ApparelAudience.mujer),
    );
    await products.saveProduct(
      'co1',
      testProduct(
        id: 'p-out',
        name: 'Hombre sin stock',
        sku: 'TST-0002',
        audience: ApparelAudience.hombre,
        stock: 0,
      ),
    );
    final store = await _store(
      companies: companies,
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
      requests: FakeCatalogRequestAccess(),
    );
    addTearDown(store.dispose);

    expect(store.visibleAudiences, [ApparelAudience.mujer]);
    expect(store.showAudienceFilter, isFalse);
  });

  test('guest catalog lists garments by update date', () async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct(
      'co1',
      testProduct(
        id: 'p-old',
        name: 'Remera vieja',
        sku: 'OLD-0001',
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 2),
      ),
    );
    await products.saveProduct(
      'co1',
      testProduct(
        id: 'p-new',
        name: 'Remera nueva',
        sku: 'NEW-0001',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    final store = await _store(
      companies: companies,
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
      requests: FakeCatalogRequestAccess(),
    );
    addTearDown(store.dispose);

    expect(store.visibleProducts.map((p) => p.id), ['p-new', 'p-old']);
  });

  test('guest catalog hides out of stock until name or code search', () async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct(
      'co1',
      testProduct(id: 'p-in', name: 'Remera lisa', brand: 'Urban'),
    );
    await products.saveProduct(
      'co1',
      testProduct(
        id: 'p-out',
        name: 'Remera vieja',
        sku: 'OUT-0001',
        category: ApparelCategory.musculosas,
        brand: 'Urban',
        stock: 0,
      ),
    );
    final store = await _store(
      companies: companies,
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
      requests: FakeCatalogRequestAccess(),
    );
    addTearDown(store.dispose);

    expect(store.visibleProducts.map((p) => p.id), ['p-in']);

    store.setSearch('remera');
    expect(store.visibleProducts.map((p) => p.id), ['p-in', 'p-out']);

    store.setSearch('out-0001');
    expect(store.visibleProducts.map((p) => p.id), ['p-out']);

    store.setSearch('out-0001-m-negro');
    expect(store.visibleProducts.map((p) => p.id), ['p-out']);

    store.setSearch('urban');
    expect(store.visibleProducts.map((p) => p.id), ['p-in']);
  });
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
