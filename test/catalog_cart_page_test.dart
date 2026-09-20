import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/catalog_bindings.dart';
import 'package:store_app/features/catalog/catalog_cart_page.dart';
import 'package:store_app/models/company.dart';

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
  });
}
