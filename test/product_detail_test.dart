import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/features/product/product_detail_page.dart';
import 'package:store_app/features/product/product_holders.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/routing/app_router.dart';
import 'package:store_app/widgets/product_image.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/session_harness.dart';

const _images = ['gallery-one', 'gallery-two', 'gallery-three'];

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AppStore> _storeWithGallery() async {
  final store = AppStore();
  await store.upsertProduct(testProduct().copyWith(images: _images));
  return store;
}

Widget _app(AppStore store) {
  return ChangeNotifierProvider.value(
    value: store,
    child: const MaterialApp(
      home: Scaffold(body: ProductDetailPage(id: 'p-test')),
    ),
  );
}

PageController _pagerController(WidgetTester tester) {
  return tester.widget<PageView>(find.byType(PageView)).controller!;
}

void main() {
  testWidgets('detail shows garment size and equivalent size', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    await store.upsertProduct(
      testProduct().copyWith(
        variants: const [
          ProductVariant(
            size: 'L',
            color: 'Negro',
            colorHex: '#1E1E1E',
            stock: 4,
          ),
          ProductVariant(
            size: 'XXS',
            color: 'Negro',
            colorHex: '#1E1E1E',
            stock: 2,
          ),
          ProductVariant(
            size: 'M',
            color: 'Negro',
            colorHex: '#1E1E1E',
            stock: 10,
          ),
        ],
        equivalentSizes: const {'M': '38', 'L': '42', 'XXS': '34'},
      ),
    );
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.text('TALLE EN PRENDA'), findsOneWidget);
    expect(find.text('TALLE EQUIVALENTE'), findsOneWidget);
    expect(find.text('XXS / M / L'), findsOneWidget);
    expect(find.text('34 / 38 / 42'), findsOneWidget);
    expect(find.text('16 en stock'), findsOneWidget);
  });

  testWidgets('detail shows how many units remain of each size and color', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    await store.upsertProduct(
      testProduct().copyWith(
        variants: const [
          ProductVariant(
            size: 'L',
            color: 'Rosa',
            colorHex: '#E091A8',
            stock: 3,
          ),
          ProductVariant(
            size: 'M',
            color: 'Negro',
            colorHex: '#1E1E1E',
            stock: 5,
          ),
        ],
      ),
    );
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.text('8 en stock'), findsOneWidget);
    final pink = find.byKey(const ValueKey('variant-size-Rosa-L'));
    await tester.ensureVisible(pink);
    await tester.pump();
    expect(find.text('Rosa'), findsOneWidget);
    expect(find.text('3 u.'), findsOneWidget);
    expect(
      find.descendant(of: pink, matching: find.text('3u')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('variant-size-Negro-M')),
        matching: find.text('5u'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('swipe shows the next product image', (tester) async {
    _setPhoneView(tester);
    await tester.pumpWidget(_app(await _storeWithGallery()));
    await tester.pump();

    expect(_pagerController(tester).page, 0);
    expect(
      find.byKey(ValueKey('product-pager-image-0-${_images[0]}')),
      findsOneWidget,
    );

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 1);
    expect(
      find.byKey(ValueKey('product-pager-image-1-${_images[1]}')),
      findsOneWidget,
    );
    final visible = tester.widget<ProductImage>(
      find.byKey(ValueKey('product-pager-image-1-${_images[1]}')),
    );
    expect(visible.path, _images[1]);
    expect(visible.fit, BoxFit.contain);
  });

  testWidgets('mouse drag shows the next product image', (tester) async {
    _setPhoneView(tester);
    await tester.pumpWidget(_app(await _storeWithGallery()));
    await tester.pump();

    await tester.drag(
      find.byType(PageView),
      const Offset(-320, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 1);
  });

  testWidgets('tap on a thumbnail shows that image', (tester) async {
    _setPhoneView(tester);
    await tester.pumpWidget(_app(await _storeWithGallery()));
    await tester.pump();

    final thumb = find.byKey(const ValueKey('product-gallery-thumb-2'));
    await tester.ensureVisible(thumb);
    await tester.tap(thumb);
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 2);
    final visible = tester.widget<ProductImage>(
      find.byKey(ValueKey('product-pager-image-2-${_images[2]}')),
    );
    expect(visible.path, _images[2]);
    expect(visible.fit, BoxFit.contain);
    final thumbImage = tester.widget<ProductImage>(
      find.descendant(of: thumb, matching: find.byType(ProductImage)),
    );
    expect(thumbImage.fit, BoxFit.contain);
  });

  testWidgets('tap on the main image opens a larger viewer', (tester) async {
    _setPhoneView(tester);
    await tester.pumpWidget(_app(await _storeWithGallery()));
    await tester.pump();

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

  testWidgets('no open order asks which order to use', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct());
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.text('Agregar al pedido'));
    await tester.pumpAndSettle();

    expect(find.text('¿A qué pedido lo agregamos?'), findsOneWidget);
    expect(find.text('Nuevo pedido'), findsOneWidget);
  });

  testWidgets('one open order still asks which order to use', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);

    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.text('Agregar al pedido'));
    await tester.pumpAndSettle();

    expect(find.text('¿A qué pedido lo agregamos?'), findsOneWidget);
    expect(find.byKey(ValueKey('order-target-${order.id}')), findsOneWidget);
    expect(find.text('Nuevo pedido'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('order-target-new'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(ValueKey('order-target-${order.id}'))).dy,
      ),
    );
  });

  testWidgets('several open orders put the last used first', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct());
    final product = store.productById('p-test')!;
    final monica = await seedTestCustomer(store);
    final ana = await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-ana', name: 'Ana López'),
    );
    final first = store.createOrder(monica);
    final second = store.createOrder(ana);
    expect(
      store.addToOrder(product, product.variants.first, orderId: second.id),
      isTrue,
    );
    store.setActiveOrder(first.id);

    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.text('Agregar al pedido'));
    await tester.pumpAndSettle();

    expect(find.text('¿A qué pedido lo agregamos?'), findsOneWidget);
    final nuevo = tester.getTopLeft(
      find.byKey(const ValueKey('order-target-new')),
    );
    final lastUsed = tester.getTopLeft(
      find.byKey(ValueKey('order-target-${second.id}')),
    );
    final other = tester.getTopLeft(
      find.byKey(ValueKey('order-target-${first.id}')),
    );
    expect(nuevo.dy, lessThan(lastUsed.dy));
    expect(lastUsed.dy, lessThan(other.dy));
    expect(find.textContaining('último usado'), findsOneWidget);
  });

  testWidgets('order picker search keeps new order first and filters', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct());
    final monica = await seedTestCustomer(store);
    final ana = await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-ana', name: 'Ana López'),
    );
    final first = store.createOrder(monica);
    final second = store.createOrder(ana);

    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.text('Agregar al pedido'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('order-target-search')), findsOneWidget);
    expect(find.byKey(ValueKey('order-target-${first.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('order-target-${second.id}')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('order-target-search')),
      'ana',
    );
    await tester.pumpAndSettle();

    expect(find.text('Nuevo pedido'), findsOneWidget);
    expect(find.byKey(ValueKey('order-target-${first.id}')), findsNothing);
    expect(find.byKey(ValueKey('order-target-${second.id}')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('order-target-new'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(ValueKey('order-target-${second.id}'))).dy,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('order-target-search')),
      'no existe',
    );
    await tester.pumpAndSettle();

    expect(find.text('Nuevo pedido'), findsOneWidget);
    expect(find.text('No hay pedidos con ese nombre'), findsOneWidget);
    expect(find.byKey(ValueKey('order-target-${second.id}')), findsNothing);
  });

  testWidgets('back from an order opened by adding returns to the product', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final order = await seedTestOrder(store);
    final router = createRouter(session);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: session),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/producto/p-test');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar al pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('order-target-${order.id}')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/pedido/${order.id}');
    expect(find.text('Buscar productos para agregar...'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('leave-order')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/producto/p-test');
    expect(find.text('Detalle de producto'), findsOneWidget);
    expect(find.text('Remera test'), findsOneWidget);
  });

  testWidgets('back from an order opened in the list still leaves the order', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final order = await seedTestOrder(store);
    final router = createRouter(session);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: session),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/pedido');
    await tester.pumpAndSettle();
    await tester.tap(find.text(order.customer.name));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/pedido/${order.id}');

    await tester.tap(find.byKey(const ValueKey('leave-order')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/pedido');
    expect(find.text('Pedidos'), findsWidgets);
    expect(find.text('Detalle de producto'), findsNothing);
  });

  testWidgets('holders sheet lists who took each color and size', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(
      testProduct().copyWith(
        variants: const [
          ProductVariant(
            size: 'M',
            color: 'Negro',
            colorHex: '#1E1E1E',
            stock: 6,
          ),
          ProductVariant(
            size: 'L',
            color: 'Rosa',
            colorHex: '#E091A8',
            stock: 4,
          ),
        ],
        equivalentSizes: const {'M': '38', 'L': '42'},
      ),
    );
    final product = store.productById('p-test')!;
    final monica = await seedTestCustomer(store);
    final ana = await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-ana', name: 'Ana López'),
    );
    final closed = store.createOrder(monica);
    expect(
      store.addToOrder(
        product,
        product.variants.firstWhere((variant) => variant.color == 'Negro'),
        orderId: closed.id,
      ),
      isTrue,
    );
    expect(store.closeOrder(closed.id), isTrue);
    final open = store.createOrder(ana);
    expect(
      store.addToOrder(
        product,
        product.variants.firstWhere((variant) => variant.color == 'Rosa'),
        quantity: 2,
        orderId: open.id,
      ),
      isTrue,
    );

    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('product-holders')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-holders-sheet')), findsOneWidget);
    expect(find.text('2 clientes · 3 prendas'), findsOneWidget);
    expect(find.text('Mónica Fernández'), findsOneWidget);
    expect(find.textContaining('Negro · Talle M (38) · 1 u.'), findsOneWidget);
    expect(find.textContaining('Cerrado'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.textContaining('Rosa · Talle L (42) · 2 u.'), findsOneWidget);
    expect(find.textContaining('Activo'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Mónica Fernández')).dy,
      lessThan(tester.getTopLeft(find.text('Ana López')).dy),
    );
  });

  testWidgets('holders sheet explains when nobody took the garment', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct());

    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('product-holders')));
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía ningún cliente se llevó esta prenda.'),
      findsOneWidget,
    );
  });

  test('holders merge the same color and size inside one order', () {
    final product = testProduct();
    final customer = testCustomer();
    final stamp = DateTime.utc(2026, 9, 11);
    final order = DraftOrder(
      id: 'o-1',
      orderNumber: 'PED-1',
      customer: customer,
      createdAt: stamp,
      updatedAt: stamp,
      lines: [
        OrderLine(
          product: product,
          variant: product.variants.first,
          quantity: 1,
        ),
        OrderLine(
          product: product,
          variant: product.variants.first,
          quantity: 2,
        ),
      ],
    );

    final holders = holdersForProduct(product.id, [order]);

    expect(holders, hasLength(1));
    expect(holders.single.quantity, 3);
    expect(holders.single.variant.color, 'Negro');
  });
}
