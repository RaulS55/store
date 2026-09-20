import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/catalog_bindings.dart';
import 'package:store_app/features/catalog/catalog_product_page.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/widgets/product_image.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_company_access.dart';
import 'fakes/fake_customer_access.dart';
import 'fakes/fake_order_access.dart';
import 'fakes/fake_product_access.dart';

const _images = ['gallery-one', 'gallery-two', 'gallery-three'];

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

PageController _pagerController(WidgetTester tester) {
  return tester.widget<PageView>(find.byType(PageView)).controller!;
}

Future<CatalogBindings> _bindingsWithGallery() async {
  final companies = FakeCompanyAccess()
    ..companies['co1'] = Company(
      id: 'co1',
      name: 'Moda Stock',
      ownerId: 'u1',
      createdAt: DateTime.utc(2026, 9, 11),
    );
  final products = FakeProductAccess();
  await products.saveProduct('co1', testProduct().copyWith(images: _images));
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
    initialLocation: '/catalogo/co1/producto/p-test',
    routes: [
      GoRoute(
        path: '/catalogo/:companyId',
        builder: (_, _) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: 'producto/:id',
            builder: (context, state) =>
                CatalogProductPage(id: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  return Provider.value(
    value: bindings,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('client catalog swipe shows the next product image', (
    tester,
  ) async {
    _setPhoneView(tester);
    final bindings = await _bindingsWithGallery();
    addTearDown(bindings.dispose);
    await tester.pumpWidget(_app(bindings));
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 0);
    expect(
      find.byKey(ValueKey('product-pager-image-0-${_images[0]}')),
      findsOneWidget,
    );

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 1);
    final visible = tester.widget<ProductImage>(
      find.byKey(ValueKey('product-pager-image-1-${_images[1]}')),
    );
    expect(visible.path, _images[1]);
  });

  testWidgets('client catalog mouse drag shows the next product image', (
    tester,
  ) async {
    _setPhoneView(tester);
    final bindings = await _bindingsWithGallery();
    addTearDown(bindings.dispose);
    await tester.pumpWidget(_app(bindings));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(PageView),
      const Offset(-320, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 1);
  });

  testWidgets('client catalog tap on a thumbnail shows that image', (
    tester,
  ) async {
    _setPhoneView(tester);
    final bindings = await _bindingsWithGallery();
    addTearDown(bindings.dispose);
    await tester.pumpWidget(_app(bindings));
    await tester.pumpAndSettle();

    final thumb = find.byKey(const ValueKey('product-gallery-thumb-2'));
    await tester.ensureVisible(thumb);
    await tester.tap(thumb);
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 2);
    final visible = tester.widget<ProductImage>(
      find.byKey(ValueKey('product-pager-image-2-${_images[2]}')),
    );
    expect(visible.path, _images[2]);
  });

  testWidgets('client catalog tap on the main image opens a larger viewer', (
    tester,
  ) async {
    _setPhoneView(tester);
    final bindings = await _bindingsWithGallery();
    addTearDown(bindings.dispose);
    await tester.pumpWidget(_app(bindings));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('product-pager-open-0-${_images[0]}')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-image-viewer')), findsOneWidget);
    expect(
      find.byKey(ValueKey('product-image-viewer-image-0-${_images[0]}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('product-image-viewer-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-image-viewer')), findsNothing);
  });

  testWidgets('adding a garment shows a confirmation', (tester) async {
    _setPhoneView(tester);
    final bindings = await _bindingsWithGallery();
    addTearDown(bindings.dispose);
    await tester.pumpWidget(_app(bindings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar al pedido'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('catalog-added-snackbar')),
      findsOneWidget,
    );
    expect(find.text('Agregamos Remera test al pedido.'), findsOneWidget);
    expect(bindings.storeFor('co1').cartCount, 1);
  });
}
