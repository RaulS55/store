import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/product_share.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/features/catalog/catalog_routes.dart';
import 'package:store_app/features/product/product_detail_page.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/session_harness.dart';

void main() {
  test('the shared link is the public catalog product', () {
    expect(
      catalogProductShareUrl('co1', 'p-test'),
      'https://app.modastore.org/catalogo/co1/producto/p-test',
    );
    expect(
      productShareText(
        name: 'Remera test',
        url: 'https://app.modastore.org/catalogo/co1/producto/p-test',
      ),
      'Remera test\nhttps://app.modastore.org/catalogo/co1/producto/p-test',
    );
    expect(productLinkUsesShareSheet(platform: TargetPlatform.macOS), isFalse);
    expect(productLinkUsesShareSheet(platform: TargetPlatform.iOS), isTrue);
    expect(productLinkUsesShareSheet(platform: TargetPlatform.android), isTrue);
  });

  test(
    'desktop copies the catalog link and never opens the share sheet',
    () async {
      String? copied;
      var shared = false;
      final outcome = await shareProductLink(
        text:
            'Remera test\nhttps://app.modastore.org/catalogo/co1/producto/p-test',
        url: 'https://app.modastore.org/catalogo/co1/producto/p-test',
        title: 'Remera test',
        useShareSheet: false,
        copy: (url) async {
          copied = url;
          return true;
        },
        share: (_) async => shared = true,
      );
      expect(outcome, ProductShareOutcome.copied);
      expect(copied, 'https://app.modastore.org/catalogo/co1/producto/p-test');
      expect(shared, isFalse);
    },
  );

  test('mobile share sheet does not fall back to mail', () async {
    ShareParams? params;
    final outcome = await shareProductLink(
      text:
          'Remera test\nhttps://app.modastore.org/catalogo/co1/producto/p-test',
      url: 'https://app.modastore.org/catalogo/co1/producto/p-test',
      title: 'Remera test',
      useShareSheet: true,
      share: (value) async => params = value,
    );
    expect(outcome, ProductShareOutcome.shared);
    expect(
      params?.text,
      'Remera test\nhttps://app.modastore.org/catalogo/co1/producto/p-test',
    );
    expect(params?.mailToFallbackEnabled, isFalse);
  });

  test('mobile copies the link when the share sheet is unavailable', () async {
    String? copied;
    final outcome = await shareProductLink(
      text:
          'Remera test\nhttps://app.modastore.org/catalogo/co1/producto/p-test',
      url: 'https://app.modastore.org/catalogo/co1/producto/p-test',
      title: 'Remera test',
      useShareSheet: true,
      copy: (url) async {
        copied = url;
        return true;
      },
      share: (_) async => throw StateError('unavailable'),
    );
    expect(outcome, ProductShareOutcome.copied);
    expect(copied, 'https://app.modastore.org/catalogo/co1/producto/p-test');
  });

  testWidgets('product detail shares the catalog link without saving', (
    tester,
  ) async {
    _phone(tester);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final store = AppStore();
    addTearDown(store.dispose);
    store.bindCompany(session.companyId);
    await store.upsertProduct(testProduct());
    final before = store.productById('p-test')!;
    String? shared;

    await tester.pumpWidget(
      _detailApp(
        store: store,
        session: session,
        share:
            ({
              required text,
              required url,
              required title,
              sharePositionOrigin,
            }) async {
              shared = url;
              expect(title, 'Remera test');
              expect(text, 'Remera test\n$url');
              return ProductShareOutcome.shared;
            },
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('share-product')));
    await tester.pump();

    final companyId = session.companyId!;
    expect(
      shared,
      'https://app.modastore.org/catalogo/$companyId/producto/p-test',
    );
    expect(store.productById('p-test')!.updatedAt, before.updatedAt);
  });

  testWidgets('sharing copies the catalog link on desktop', (tester) async {
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

    expect(called, isFalse);
    expect(find.text('No se pudo compartir la prenda.'), findsOneWidget);
  });
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _detailApp({
  required AppStore store,
  required ProductLinkSharer share,
  SessionStore? session,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      if (session != null) ChangeNotifierProvider.value(value: session),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ProductDetailPage(id: 'p-test', shareProduct: share),
      ),
    ),
  );
}
