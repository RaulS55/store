import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/catalog_bindings.dart';
import 'package:store_app/features/catalog/catalog_cart_page.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/widgets/qty_stepper.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_company_access.dart';
import 'fakes/fake_customer_access.dart';
import 'fakes/fake_order_access.dart';
import 'fakes/fake_product_access.dart';

FilledButton _sendButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.byKey(const ValueKey('catalog-send')),
  );
}

void main() {
  testWidgets('whatsapp send stays off until the client types a name', (
    tester,
  ) async {
    final companies = FakeCompanyAccess()
      ..companies['co1'] = Company(
        id: 'co1',
        name: 'Moda Stock',
        ownerId: 'u1',
        createdAt: DateTime.utc(2026, 9, 11),
        phone: '+54 9 11 4555-0101',
      );
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final bindings = CatalogBindings(
      companies: companies,
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
    );
    addTearDown(bindings.dispose);

    final store = bindings.storeFor('co1');
    await store.ready;
    final product = store.visibleProducts.single;
    store.addToCart(product, product.variants.first);

    final router = GoRouter(
      initialLocation: '/catalogo/co1/pedido',
      routes: [
        GoRoute(
          path: '/catalogo/:companyId',
          builder: (_, _) => const SizedBox.shrink(),
          routes: [
            GoRoute(path: 'pedido', builder: (_, _) => const CatalogCartPage()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      Provider.value(
        value: bindings,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(_sendButton(tester).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('catalog-client-name')),
      'J',
    );
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('catalog-client-name')),
      'Juan',
    );
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNotNull);
    expect(find.text('Realizar pedido'), findsOneWidget);
  });

  testWidgets('an open catalog order shows its id and the update action', (
    tester,
  ) async {
    final companies = FakeCompanyAccess()
      ..companies['co1'] = Company(
        id: 'co1',
        name: 'Moda Stock',
        ownerId: 'u1',
        createdAt: DateTime.utc(2026, 9, 11),
        phone: '+54 9 11 4555-0101',
      );
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final bindings = CatalogBindings(
      companies: companies,
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
    );
    addTearDown(bindings.dispose);

    final store = bindings.storeFor('co1');
    await store.ready;
    final product = store.visibleProducts.single;
    store.addToCart(product, product.variants.first);
    final submitted = await store.submit(name: 'Juan');

    final router = GoRouter(
      initialLocation: '/catalogo/co1/pedido',
      routes: [
        GoRoute(
          path: '/catalogo/:companyId',
          builder: (_, _) => const SizedBox.shrink(),
          routes: [
            GoRoute(path: 'pedido', builder: (_, _) => const CatalogCartPage()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      Provider.value(
        value: bindings,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('catalog-open-order')), findsOneWidget);
    expect(find.textContaining(submitted.order.orderNumber), findsOneWidget);
    expect(find.text('Actualizar pedido'), findsOneWidget);
    expect(find.text('Ya solicitado'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('catalog-requested-separator')),
      findsOneWidget,
    );
    expect(find.byType(QtyStepper), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(_sendButton(tester).onPressed, isNull);
    expect(find.text('Juan'), findsOneWidget);
    expect(find.text('Nuevo'), findsNothing);
    expect(find.text('Total'), findsOneWidget);
  });

  testWidgets('update stays off until the client adds new garments', (
    tester,
  ) async {
    final companies = FakeCompanyAccess()
      ..companies['co1'] = Company(
        id: 'co1',
        name: 'Moda Stock',
        ownerId: 'u1',
        createdAt: DateTime.utc(2026, 9, 11),
        phone: '+54 9 11 4555-0101',
      );
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final bindings = CatalogBindings(
      companies: companies,
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
    );
    addTearDown(bindings.dispose);

    final store = bindings.storeFor('co1');
    await store.ready;
    final product = store.visibleProducts.single;
    store.addToCart(product, product.variants.first);
    await store.submit(name: 'Juan');
    store.addToCart(product, product.variants.first);

    final router = GoRouter(
      initialLocation: '/catalogo/co1/pedido',
      routes: [
        GoRoute(
          path: '/catalogo/:companyId',
          builder: (_, _) => const SizedBox.shrink(),
          routes: [
            GoRoute(path: 'pedido', builder: (_, _) => const CatalogCartPage()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      Provider.value(
        value: bindings,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ya solicitado'), findsOneWidget);
    expect(find.byType(QtyStepper), findsOneWidget);
    expect(_sendButton(tester).onPressed, isNotNull);
    expect(find.text('Actualizar pedido'), findsOneWidget);
    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('Total del pedido'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('catalog-new-total'))).data,
      '\$10.000,00',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('catalog-cart-total')))
          .data,
      '\$20.000,00',
    );
  });
}
