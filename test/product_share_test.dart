import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/catalog_bindings.dart';
import 'package:store_app/data/product_share.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/data/share_link_access.dart';
import 'package:store_app/features/catalog/product_share_page.dart';
import 'package:store_app/features/product/product_detail_page.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/models/share_code.dart';
import 'package:store_app/routing/app_entry.dart';
import 'package:store_app/routing/app_router.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_catalog_request_access.dart';
import 'fakes/fake_company_access.dart';
import 'fakes/fake_customer_access.dart';
import 'fakes/fake_order_access.dart';
import 'fakes/fake_product_access.dart';
import 'fakes/fake_share_link_access.dart';
import 'fakes/session_harness.dart';

void main() {
  test('share codes stay short and unambiguous', () {
    expect(generateShareCode(FakeRandom()).length, shareCodeLength);
    expect(isShareCode('k7m2q'), isTrue);
    expect(readShareCode(' k7m2q '), 'k7m2q');
    expect(readShareCode('k7m2i'), isNull);
    expect(readShareCode('K7M2Q'), isNull);
    expect(readShareCode('k7m2'), isNull);
    expect(productShareUrl('k7m2q'), 'https://app.modastore.org/p/k7m2q');
    expect(
      productShareText(
        name: 'Remera test',
        url: 'https://app.modastore.org/p/k7m2q',
      ),
      'Remera test\nhttps://app.modastore.org/p/k7m2q',
    );
    final stored = Product.fromMap(
      'p-test',
      testProduct().copyWith(shareCode: 'k7m2q').toMap(),
    );
    expect(stored.shareCode, 'k7m2q');
    expect(testProduct().toMap().containsKey('shareCode'), isFalse);
    expect(isProductShareLocation('/p/k7m2q'), isTrue);
    expect(isProductShareLocation('/producto/p-test'), isFalse);
    expect(isProductShareLocation('/pedido'), isFalse);
    expect(productLinkUsesShareSheet(platform: TargetPlatform.macOS), isFalse);
    expect(productLinkUsesShareSheet(platform: TargetPlatform.iOS), isTrue);
    expect(productLinkUsesShareSheet(platform: TargetPlatform.android), isTrue);
  });

  test('desktop copies the link and never opens the share sheet', () async {
    String? copied;
    var shared = false;
    final outcome = await shareProductLink(
      text: 'Remera test\nhttps://app.modastore.org/p/k7m2q',
      url: 'https://app.modastore.org/p/k7m2q',
      title: 'Remera test',
      useShareSheet: false,
      copy: (url) async {
        copied = url;
        return true;
      },
      share: (_) async => shared = true,
    );
    expect(outcome, ProductShareOutcome.copied);
    expect(copied, 'https://app.modastore.org/p/k7m2q');
    expect(shared, isFalse);
  });

  test('mobile share sheet does not fall back to mail', () async {
    ShareParams? params;
    final outcome = await shareProductLink(
      text: 'Remera test\nhttps://app.modastore.org/p/k7m2q',
      url: 'https://app.modastore.org/p/k7m2q',
      title: 'Remera test',
      useShareSheet: true,
      share: (value) async => params = value,
    );
    expect(outcome, ProductShareOutcome.shared);
    expect(params?.text, 'Remera test\nhttps://app.modastore.org/p/k7m2q');
    expect(params?.mailToFallbackEnabled, isFalse);
  });

  test('mobile copies the link when the share sheet is unavailable', () async {
    String? copied;
    final outcome = await shareProductLink(
      text: 'Remera test\nhttps://app.modastore.org/p/k7m2q',
      url: 'https://app.modastore.org/p/k7m2q',
      title: 'Remera test',
      useShareSheet: true,
      copy: (url) async {
        copied = url;
        return true;
      },
      share: (_) async => throw StateError('unavailable'),
    );
    expect(outcome, ProductShareOutcome.copied);
    expect(copied, 'https://app.modastore.org/p/k7m2q');
  });

  test('a product keeps the same share code', () async {
    final links = FakeShareLinkAccess();
    final product = testProduct();
    final saved = <Product>[];
    final code = await ensureProductShareCode(
      companyId: 'co1',
      product: product,
      links: links,
      saveProduct: (next) async => saved.add(next),
      nextCode: () => 'k7m2q',
    );
    expect(code, 'k7m2q');
    expect(saved.single.shareCode, 'k7m2q');
    expect(links.links['k7m2q']!.productId, product.id);

    saved.clear();
    final again = await ensureProductShareCode(
      companyId: 'co1',
      product: savedProduct(product, 'k7m2q'),
      links: links,
      saveProduct: (next) async => saved.add(next),
      nextCode: () => 'zzzzz',
    );
    expect(again, 'k7m2q');
    expect(saved, isEmpty);
    expect(links.links, hasLength(1));
  });

  test('a missing link is repaired without a new code', () async {
    final links = FakeShareLinkAccess();
    final saved = <Product>[];
    final code = await ensureProductShareCode(
      companyId: 'co1',
      product: testProduct().copyWith(shareCode: 'k7m2q'),
      links: links,
      saveProduct: (next) async => saved.add(next),
      nextCode: () => 'zzzzz',
    );
    expect(code, 'k7m2q');
    expect(saved, isEmpty);
    expect(links.links['k7m2q']!.companyId, 'co1');
  });

  test('a taken code is skipped', () async {
    final links = FakeShareLinkAccess()
      ..links['k7m2q'] = const ProductShareLink(
        code: 'k7m2q',
        companyId: 'other',
        productId: 'other-product',
      );
    final codes = ['k7m2q', 'ab3cd'];
    final code = await ensureProductShareCode(
      companyId: 'co1',
      product: testProduct(),
      links: links,
      saveProduct: (_) async {},
      nextCode: () => codes.removeAt(0),
    );
    expect(code, 'ab3cd');
    expect(links.links['ab3cd']!.productId, 'p-test');
  });

  test('short product links stay public', () async {
    final session = createSessionStore();
    addTearDown(session.dispose);
    expect(session.isReady, isFalse);
    expect(sessionRedirect(session, '/p/k7m2q'), isNull);
    expect(sessionRedirect(session, '/producto/p-test'), '/cargando');

    session.start();
    for (var i = 0; i < 20 && !session.isReady; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sessionRedirect(session, '/p/k7m2q'), isNull);
    expect(sessionRedirect(session, '/producto/p-test'), '/ingresar');

    final owner = await signedInOwnerSession();
    addTearDown(owner.dispose);
    expect(sessionRedirect(owner, '/p/k7m2q'), isNull);
  });

  testWidgets('a short link opens that garment in the catalog', (tester) async {
    _phone(tester);
    final bindings = await _catalog();
    final links = FakeShareLinkAccess()
      ..links['k7m2q'] = const ProductShareLink(
        code: 'k7m2q',
        companyId: 'co1',
        productId: 'p-test',
      );

    await tester.pumpWidget(_shareApp(bindings, links, '/p/k7m2q'));
    await tester.pumpAndSettle();

    expect(find.text('Remera test'), findsOneWidget);
    expect(find.text('Agregar al pedido'), findsOneWidget);
  });

  testWidgets('an unknown short link says the garment is missing', (
    tester,
  ) async {
    final bindings = await _catalog();
    await tester.pumpWidget(
      _shareApp(bindings, FakeShareLinkAccess(), '/p/k7m2q'),
    );
    await tester.pumpAndSettle();

    expect(find.text('No encontramos esta prenda.'), findsOneWidget);
    expect(find.text('Remera test'), findsNothing);
  });

  testWidgets('product detail shares the short link and reuses it', (
    tester,
  ) async {
    _phone(tester);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final store = AppStore();
    addTearDown(store.dispose);
    store.bindCompany(session.companyId);
    await store.upsertProduct(testProduct());
    final links = FakeShareLinkAccess();
    final shared = <String>[];

    Future<ProductShareOutcome> capture({
      required String text,
      required String url,
      required String title,
      Rect? sharePositionOrigin,
    }) async {
      shared.add(text);
      expect(title, 'Remera test');
      expect(text, 'Remera test\n$url');
      expect(
        url,
        matches(RegExp(r'^https://app\.modastore\.org/p/[a-z2-9]{5}$')),
      );
      return ProductShareOutcome.shared;
    }

    await tester.pumpWidget(
      _detailApp(store: store, session: session, links: links, share: capture),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('share-product')));
    await tester.pump();
    await tester.pump();

    expect(shared, hasLength(1));
    final code = store.productById('p-test')!.shareCode!;
    expect(shared.single, 'Remera test\nhttps://app.modastore.org/p/$code');
    expect(links.links[code]!.companyId, session.companyId);

    await tester.tap(find.byKey(const ValueKey('share-product')));
    await tester.pump();
    await tester.pump();

    expect(shared, [
      'Remera test\nhttps://app.modastore.org/p/$code',
      'Remera test\nhttps://app.modastore.org/p/$code',
    ]);
    expect(links.links, hasLength(1));
  });

  testWidgets('sharing copies the link when the sheet is unavailable', (
    tester,
  ) async {
    _phone(tester);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final store = AppStore();
    addTearDown(store.dispose);
    store.bindCompany(session.companyId);
    await store.upsertProduct(testProduct());

    await tester.pumpWidget(
      _detailApp(
        store: store,
        session: session,
        links: FakeShareLinkAccess(),
        share:
            ({
              required text,
              required url,
              required title,
              sharePositionOrigin,
            }) async => ProductShareOutcome.copied,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('share-product')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Copiamos el enlace.'), findsOneWidget);
  });

  testWidgets('sharing fails without a company', (tester) async {
    _phone(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct());
    var called = false;

    await tester.pumpWidget(
      _detailApp(
        store: store,
        links: FakeShareLinkAccess(),
        share:
            ({
              required text,
              required url,
              required title,
              sharePositionOrigin,
            }) async {
              called = true;
              return ProductShareOutcome.shared;
            },
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('share-product')));
    await tester.pump();
    await tester.pump();

    expect(called, isFalse);
    expect(find.text('No se pudo compartir la prenda.'), findsOneWidget);
  });
}

Product savedProduct(Product product, String code) {
  return product.copyWith(shareCode: code);
}

class FakeRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<CatalogBindings> _catalog() async {
  final companies = FakeCompanyAccess()
    ..companies['co1'] = Company(
      id: 'co1',
      name: 'Moda Stock',
      ownerId: 'u1',
      createdAt: DateTime.utc(2026, 9, 11),
    );
  final products = FakeProductAccess();
  await products.saveProduct('co1', testProduct());
  return CatalogBindings(
    companies: companies,
    products: products,
    customers: FakeCustomerAccess(),
    orders: FakeOrderAccess(),
    requests: FakeCatalogRequestAccess(),
  );
}

Widget _shareApp(CatalogBindings bindings, ShareLinkAccess links, String path) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/p/:code',
        builder: (context, state) =>
            ProductSharePage(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/catalogo/:companyId',
        builder: (_, _) => const SizedBox.shrink(),
        routes: [
          GoRoute(path: 'pedido', builder: (_, _) => const SizedBox.shrink()),
        ],
      ),
    ],
  );
  return MultiProvider(
    providers: [
      Provider.value(value: bindings),
      Provider<ShareLinkAccess>.value(value: links),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _detailApp({
  required AppStore store,
  required ShareLinkAccess links,
  required ProductLinkSharer share,
  SessionStore? session,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      if (session != null) ChangeNotifierProvider.value(value: session),
      Provider<ShareLinkAccess>.value(value: links),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ProductDetailPage(id: 'p-test', shareProduct: share),
      ),
    ),
  );
}
