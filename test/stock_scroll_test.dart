import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/features/stock/stock_page.dart';
import 'package:store_app/routing/app_router.dart';
import 'package:store_app/theme/tokens.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_product_access.dart';
import 'fakes/session_harness.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app({
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

Finder _stockScrollable() {
  return find.descendant(
    of: find.byKey(StockPage.mobileScrollKey),
    matching: find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axis == Axis.vertical,
    ),
  );
}

double _stockOffset(WidgetTester tester) {
  return tester.state<ScrollableState>(_stockScrollable()).position.pixels;
}

void main() {
  testWidgets('stock keeps scroll after product detail back', (tester) async {
    _setPhoneView(tester);
    final products = FakeProductAccess();
    final store = AppStore(products: products);
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    store.bindCompany(session.companyId);

    for (var i = 0; i < 12; i++) {
      await store.upsertProduct(
        testProduct(
          id: 'p-${i.toString().padLeft(2, '0')}',
          name: 'Prenda ${i.toString().padLeft(2, '0')}',
          sku: 'SKU-${i.toString().padLeft(2, '0')}',
        ),
      );
    }

    final router = createRouter(session);
    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    const target = 'Prenda 00';
    await tester.scrollUntilVisible(
      find.text(target),
      280,
      scrollable: _stockScrollable(),
    );
    await tester.pumpAndSettle();
    final offset = _stockOffset(tester);
    expect(offset, greaterThan(0));

    await tester.tap(find.text(target));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de producto'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de producto'), findsNothing);
    expect(_stockOffset(tester), closeTo(offset, 1));
    expect(find.text(target), findsOneWidget);
  });

  testWidgets('stock page indicator does not leak ink into product detail', (
    tester,
  ) async {
    _setPhoneView(tester);
    final products = FakeProductAccess();
    final store = AppStore(products: products);
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    store.bindCompany(session.companyId);

    for (var i = 0; i < 12; i++) {
      await store.upsertProduct(
        testProduct(
          id: 'p-${i.toString().padLeft(2, '0')}',
          name: 'Prenda ${i.toString().padLeft(2, '0')}',
          sku: 'SKU-${i.toString().padLeft(2, '0')}',
        ),
      );
    }

    final router = createRouter(session);
    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stock-page-indicator')),
      280,
      scrollable: _stockScrollable(),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stock-page-indicator')), findsOneWidget);

    await tester.tap(find.textContaining('Prenda').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Detalle de producto'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stock-page-indicator')).hitTestable(),
      findsNothing,
    );

    final leakedInks = tester.widgetList<Ink>(find.byType(Ink)).where((ink) {
      final decoration = ink.decoration;
      return decoration is BoxDecoration &&
          decoration.color == AppColors.terracotta;
    });
    expect(leakedInks, isEmpty);
  });
}
