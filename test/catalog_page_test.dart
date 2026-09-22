import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/catalog_bindings.dart';
import 'package:store_app/features/catalog/catalog_page.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/models/product.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_company_access.dart';
import 'fakes/fake_customer_access.dart';
import 'fakes/fake_order_access.dart';
import 'fakes/fake_product_access.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<CatalogBindings> _bindings() async {
  final companies = FakeCompanyAccess()
    ..companies['co1'] = Company(
      id: 'co1',
      name: 'Moda Stock',
      ownerId: 'u1',
      createdAt: DateTime.utc(2026, 9, 11),
    );
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
      id: 'p-j',
      name: 'Jean hombre',
      sku: 'TST-0002',
      category: ApparelCategory.jeans,
      audience: ApparelAudience.hombre,
    ),
  );
  final bindings = CatalogBindings(
    companies: companies,
    products: products,
    customers: FakeCustomerAccess(),
    orders: FakeOrderAccess(),
  );
  await bindings.storeFor('co1').ready;
  return bindings;
}

Widget _app(CatalogBindings bindings) {
  final router = GoRouter(
    initialLocation: '/catalogo/co1',
    routes: [
      GoRoute(
        path: '/catalogo/:companyId',
        builder: (_, _) => const CatalogPage(),
      ),
    ],
  );
  return Provider.value(
    value: bindings,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('client catalog filters by category chip', (tester) async {
    _setPhoneView(tester);
    final bindings = await _bindings();
    addTearDown(bindings.dispose);
    await tester.pumpWidget(_app(bindings));
    await tester.pumpAndSettle();

    expect(find.text('Remera mujer'), findsOneWidget);
    expect(find.text('Jean hombre'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-filters')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-logo')), findsNothing);
    expect(find.byKey(const ValueKey('catalog-contacts')), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Todo'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Remeras'));
    await tester.pumpAndSettle();

    expect(find.text('Remera mujer'), findsOneWidget);
    expect(find.text('Jean hombre'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todo'));
    await tester.pumpAndSettle();
    expect(find.text('Remera mujer'), findsOneWidget);
  });

  testWidgets('client catalog opens the filter sheet', (tester) async {
    _setPhoneView(tester);
    final bindings = await _bindings();
    addTearDown(bindings.dispose);
    await tester.pumpWidget(_app(bindings));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('catalog-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Filtros'), findsOneWidget);
    expect(find.text('Aplicar filtros'), findsOneWidget);
  });

  testWidgets('client catalog shows the business logo and contact links', (
    tester,
  ) async {
    _setPhoneView(tester);
    final companies = FakeCompanyAccess()
      ..companies['co1'] = Company(
        id: 'co1',
        name: 'Casa Norte',
        ownerId: 'u1',
        createdAt: DateTime.utc(2026, 9, 11),
        phone: '+54 9 11 5555-0000',
        logoUrl: 'https://example.com/logo.jpg',
        instagram: '@casanorte',
        tiktok: 'https://www.tiktok.com/@casanorte',
        facebook: 'casanorte',
      );
    final bindings = CatalogBindings(
      companies: companies,
      products: FakeProductAccess(),
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
    );
    addTearDown(bindings.dispose);
    await bindings.storeFor('co1').ready;
    await tester.pumpWidget(_app(bindings));
    await tester.pump();

    expect(find.byKey(const ValueKey('catalog-logo')), findsOneWidget);
    expect(find.text('Casa Norte'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-contacts')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-whatsapp')), findsOneWidget);
    expect(find.text('Instagram · @casanorte'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Facebook · @casanorte'), findsOneWidget);
    expect(find.text('Contacto'), findsOneWidget);
  });
}
