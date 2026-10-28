import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/catalog_bindings.dart';
import 'package:store_app/features/catalog/catalog_page.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/models/product.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_catalog_request_access.dart';
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
    requests: FakeCatalogRequestAccess(),
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
    expect(find.widgetWithText(ChoiceChip, 'Remeras'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Jeans'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Musculosas'), findsNothing);
    expect(find.byKey(const ValueKey('audience-chip-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('audience-chip-mujer')), findsOneWidget);
    expect(find.byKey(const ValueKey('audience-chip-hombre')), findsOneWidget);
    expect(find.byKey(const ValueKey('audience-chip-bebe')), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Remeras'));
    await tester.pumpAndSettle();

    expect(find.text('Remera mujer'), findsOneWidget);
    expect(find.text('Jean hombre'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Remeras'));
    await tester.pumpAndSettle();
    expect(find.text('Remera mujer'), findsOneWidget);
    expect(find.text('Jean hombre'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todo'));
    await tester.pumpAndSettle();
    expect(find.text('Remera mujer'), findsOneWidget);
  });

  testWidgets('client catalog opens advanced filters from the side', (
    tester,
  ) async {
    _setPhoneView(tester);
    final bindings = await _bindings();
    addTearDown(bindings.dispose);
    await tester.pumpWidget(_app(bindings));
    await tester.pumpAndSettle();

    expect(find.text('Filtros avanzados'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('catalog-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Filtros avanzados'), findsOneWidget);
    final filters = tester.getTopLeft(
      find.byKey(const ValueKey('catalog-filters')),
    );
    final cart = tester.getTopLeft(find.byTooltip('Pedido'));
    expect(filters.dx, lessThan(cart.dx));
    final panel = tester.getRect(find.byType(Drawer));
    expect(panel.left, 0);
    expect(panel.right, lessThan(400));
    expect(
      tester.widget<Drawer>(find.byType(Drawer)).backgroundColor,
      Colors.white,
    );
    expect(find.text('Aplicar filtros'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Remeras'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Jeans'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Musculosas'), findsNothing);
    expect(find.text('Público'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Mujer'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Hombre'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Bebé'), findsNothing);
  });

  testWidgets(
    'client catalog hides audience filter when only one public exists',
    (tester) async {
      _setPhoneView(tester);
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
        testProduct(audience: ApparelAudience.mujer),
      );
      final bindings = CatalogBindings(
        companies: companies,
        products: products,
        customers: FakeCustomerAccess(),
        orders: FakeOrderAccess(),
        requests: FakeCatalogRequestAccess(),
      );
      addTearDown(bindings.dispose);
      await bindings.storeFor('co1').ready;
      await tester.pumpWidget(_app(bindings));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('audience-chip-all')), findsNothing);
      expect(find.byKey(const ValueKey('audience-chip-mujer')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('catalog-filters')));
      await tester.pumpAndSettle();
      expect(find.text('Público'), findsNothing);
    },
  );

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
        instagram: const ['@casanorte', '@mayorista'],
        tiktok: const ['https://www.tiktok.com/@casanorte'],
        facebook: const ['casanorte'],
      );
    final bindings = CatalogBindings(
      companies: companies,
      products: FakeProductAccess(),
      customers: FakeCustomerAccess(),
      orders: FakeOrderAccess(),
      requests: FakeCatalogRequestAccess(),
    );
    addTearDown(bindings.dispose);
    await bindings.storeFor('co1').ready;
    await tester.pumpWidget(_app(bindings));
    await tester.pump();

    expect(find.byKey(const ValueKey('catalog-logo')), findsOneWidget);
    expect(find.text('Casa Norte'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-contacts')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-whatsapp')), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.whatsapp.data), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.instagram.data), findsNWidgets(2));
    expect(find.byIcon(FontAwesomeIcons.tiktok.data), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.facebook.data), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Contacto'), findsNothing);
    expect(find.text('Instagram · @casanorte'), findsNothing);
    expect(find.text('Instagram · @mayorista'), findsNothing);
    expect(find.text('TikTok · @casanorte'), findsNothing);
    expect(find.text('Facebook · @casanorte'), findsNothing);
    expect(find.byTooltip('WhatsApp'), findsOneWidget);
    expect(find.byTooltip('Instagram · @casanorte'), findsOneWidget);
    expect(find.byTooltip('Instagram · @mayorista'), findsOneWidget);
    expect(find.byTooltip('TikTok · @casanorte'), findsOneWidget);
    expect(find.byTooltip('Facebook · @casanorte'), findsOneWidget);
  });
}
