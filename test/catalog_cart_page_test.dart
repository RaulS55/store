import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/catalog_bindings.dart';
import 'package:store_app/features/catalog/catalog_cart_page.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/widgets/qty_stepper.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_catalog_request_access.dart';
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
  testWidgets('whatsapp send stays off until name and phone are valid', (
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
    final requests = FakeCatalogRequestAccess();
    final bindings = CatalogBindings(
      companies: companies,
      products: products,
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
      requests: requests,
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
    expect(_sendButton(tester).onPressed, isNull);

    expect(find.text('+54'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('catalog-client-phone')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.textContaining('Ej.: 11 5555-1234'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('catalog-client-phone')),
      '123',
    );
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNull);
    expect(find.textContaining('número de Argentina'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('catalog-client-phone')),
      '11 5555-1234',
    );
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNotNull);
    expect(find.text('Realizar pedido'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('catalog-send')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('el vendedor va a recibir una notificación'),
      findsOneWidget,
    );
    expect(find.textContaining('WhatsApp'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(requests.requests['co1'], isNull);

    await tester.tap(find.byKey(const ValueKey('catalog-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    final saved = requests.requests['co1']!.values.single;
    expect(saved.customerName, 'Juan');
    expect(saved.customerPhone, '+54 9 11 5555-1234');
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
      requests: FakeCatalogRequestAccess(),
    );
    addTearDown(bindings.dispose);

    final store = bindings.storeFor('co1');
    await store.ready;
    final product = store.visibleProducts.single;
    store.addToCart(product, product.variants.first);
    await store.submit(name: 'Juan', phone: '+54 9 11 5555-1234');

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

    expect(
      find.byKey(const ValueKey('catalog-awaiting-approval')),
      findsOneWidget,
    );
    expect(find.text('Esperando aprobación'), findsOneWidget);
    expect(find.text('Ya solicitado'), findsNothing);
    expect(find.text('Actualizar solicitud'), findsOneWidget);
    expect(find.text('Actualizar pedido'), findsNothing);
    expect(
      find.byKey(const ValueKey('catalog-awaiting-separator')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('catalog-open-order')), findsNothing);
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
      requests: FakeCatalogRequestAccess(),
    );
    addTearDown(bindings.dispose);

    final store = bindings.storeFor('co1');
    await store.ready;
    final product = store.visibleProducts.single;
    store.addToCart(product, product.variants.first);
    await store.submit(name: 'Juan', phone: '+54 9 11 5555-1234');
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

    expect(find.text('Esperando aprobación'), findsOneWidget);
    expect(find.byType(QtyStepper), findsOneWidget);
    expect(_sendButton(tester).onPressed, isNotNull);
    expect(find.text('Actualizar solicitud'), findsOneWidget);
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
