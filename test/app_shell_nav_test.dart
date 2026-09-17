import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/routing/app_router.dart';
import 'package:store_app/theme/app_theme.dart';

import 'fakes/fake_product_access.dart';
import 'fakes/session_harness.dart';

void _setPhoneView(WidgetTester tester, {double insetBottom = 0}) {
  tester.view.physicalSize = const Size(400, 720);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: insetBottom);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
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
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('mobile navigation bar stays on the bottom edge', (tester) async {
    _setPhoneView(tester, insetBottom: 80);
    final store = AppStore(products: FakeProductAccess());
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    store.bindCompany(session.companyId);

    final router = createRouter(session);
    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    final nav = tester.getRect(find.byType(NavigationBar));
    expect(nav.bottom, closeTo(720, 0.5));
    expect(nav.height, closeTo(68, 0.5));
  });

  testWidgets('product detail hides the mobile navigation bar', (tester) async {
    _setPhoneView(tester);
    final store = AppStore(products: FakeProductAccess());
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    store.bindCompany(session.companyId);

    final router = createRouter(session);
    router.go('/producto/nuevo');
    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    router.go('/producto/p-test');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
  });
}
