import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/features/product/product_detail_page.dart';
import 'package:store_app/features/product/product_form_page.dart';
import 'package:store_app/models/company_role.dart';
import 'package:store_app/routing/app_router.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_image_access.dart';
import 'fakes/fake_product_access.dart';
import 'fakes/session_harness.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setFormView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _detailApp({required AppStore store, required SessionStore session}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: session),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ProductDetailPage(id: 'p-test')),
    ),
  );
}

Widget _formApp({required AppStore store, required SessionStore session}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: session),
    ],
    child: const MaterialApp(
      home: Scaffold(body: ProductFormPage(id: 'p-test')),
    ),
  );
}

Widget _routerApp({
  required AppStore store,
  required SessionStore session,
  required GoRouter router,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: session),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('deleteProduct soft-deletes and removes storage images', () async {
    final products = FakeProductAccess();
    final images = FakeImageAccess();
    final store = AppStore(products: products, images: images);
    addTearDown(store.dispose);
    store.bindCompany('co1');

    final firstUrl = await store.uploadProductImage(
      productId: 'p-test',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x01]),
    );
    await store.uploadProductImage(
      productId: 'p-other',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x02]),
    );
    await store.upsertProduct(testProduct().copyWith(images: [firstUrl]));
    await store.upsertProduct(testProduct(id: 'p-other', sku: 'TST-0002'));

    await store.deleteProduct('p-test');

    expect(store.productById('p-test'), isNull);
    expect(store.cachedProductImage(firstUrl), isNull);
    expect(store.productById('p-other'), isNotNull);
    final saved = products.products['co1']!['p-test']!;
    expect(saved.isDeleted, isTrue);
    expect(saved.deletedAt, isNotNull);
    expect(images.uploads, hasLength(1));
    expect(images.uploads.single.productId, 'p-other');
  });

  testWidgets('owner can delete a garment from the detail page', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    await store.upsertProduct(testProduct());
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(_detailApp(store: store, session: session));
    await tester.pump();

    expect(find.byKey(const ValueKey('delete-product')), findsOneWidget);
    expect(find.byTooltip('Editar'), findsOneWidget);
    expect(find.byTooltip('Eliminar'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Eliminar prenda'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('delete-product')));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar prenda'), findsWidgets);
    expect(
      find.text(
        '¿Eliminar Remera test? También se borran las fotos de esta prenda.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(store.productById('p-test'), isNotNull);
  });

  testWidgets('administrator sees delete on the edit form', (tester) async {
    _setFormView(tester);
    final store = AppStore();
    await store.upsertProduct(testProduct());
    final session = await signedInMemberSession(
      role: CompanyRole.administrator,
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(_formApp(store: store, session: session));
    await tester.pump();

    expect(find.byKey(const ValueKey('delete-product')), findsOneWidget);
  });

  testWidgets('employee does not see delete on detail or form', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    await store.upsertProduct(testProduct());
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);

    await tester.pumpWidget(_detailApp(store: store, session: session));
    await tester.pump();
    expect(find.byKey(const ValueKey('delete-product')), findsNothing);

    tester.view.physicalSize = const Size(800, 2000);
    await tester.pumpWidget(_formApp(store: store, session: session));
    await tester.pump();
    expect(find.byKey(const ValueKey('delete-product')), findsNothing);
  });

  testWidgets('owner confirm delete leaves the catalog route', (tester) async {
    _setPhoneView(tester);
    final products = FakeProductAccess();
    final images = FakeImageAccess();
    final store = AppStore(products: products, images: images);
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    store.bindCompany(session.companyId);
    await store.uploadProductImage(
      productId: 'p-test',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x01]),
    );
    await store.upsertProduct(testProduct());

    final router = createRouter(session);
    await tester.pumpWidget(
      _routerApp(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();
    router.go('/producto/p-test');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-product')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(store.productById('p-test'), isNull);
    expect(images.uploads, isEmpty);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('Prenda eliminada'), findsOneWidget);
  });
}
