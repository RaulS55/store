import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/models/company_role.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/routing/app_router.dart';
import 'package:store_app/theme/app_theme.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/session_harness.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
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
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

Future<AppStore> _seedStatsStore() async {
  final store = AppStore();
  final product = testProduct(id: 'p1', stock: 8, price: 15000);
  await store.upsertProduct(product);
  final order = await seedTestOrder(store, product: product);
  expect(store.closeOrder(order.id), isTrue);
  store.closedOrders.add(
    DraftOrder(
      id: 'o-old',
      orderNumber: '99',
      customer: testCustomer(),
      lines: [
        OrderLine(
          product: product,
          variant: product.variants.first,
          quantity: 2,
        ),
      ],
      status: OrderStatus.cerrado,
      createdAt: DateTime.utc(2025, 3, 10),
      updatedAt: DateTime.utc(2025, 3, 10),
      closedAt: DateTime.utc(2025, 3, 10, 15),
    ),
  );
  return store;
}

void main() {
  testWidgets('employee more page hides Estadísticas', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/mas');
    await tester.pumpAndSettle();

    expect(find.text('Estadísticas'), findsNothing);
    expect(find.text('Clientes'), findsOneWidget);
  });

  testWidgets('owner more page shows Estadísticas', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/mas');
    await tester.pumpAndSettle();

    expect(find.text('Estadísticas'), findsOneWidget);
  });

  testWidgets('administrator more page shows Estadísticas', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInMemberSession(
      role: CompanyRole.administrator,
    );
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/mas');
    await tester.pumpAndSettle();

    expect(find.text('Estadísticas'), findsOneWidget);
  });

  testWidgets('employee is redirected away from /estadisticas', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/estadisticas');
    await tester.pumpAndSettle();

    expect(find.text('En prendas'), findsNothing);
    expect(router.state.uri.path, '/');
  });

  testWidgets('employee drawer hides Estadísticas', (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();
    router.go('/config');
    await tester.pumpAndSettle();

    expect(find.text('Estadísticas'), findsNothing);
    expect(find.text('Clientes'), findsOneWidget);
  });

  testWidgets('owner can see garment and sold totals', (tester) async {
    _setPhoneView(tester);
    final store = await _seedStatsStore();
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/estadisticas');
    await tester.pumpAndSettle();

    expect(find.text('Estadísticas'), findsWidgets);
    expect(find.text('En prendas'), findsOneWidget);
    expect(find.text('Vendido'), findsOneWidget);
    expect(find.text('7 unidades'), findsOneWidget);
    expect(find.text('\$105.000'), findsOneWidget);
    expect(find.text('3 unidades'), findsOneWidget);
    expect(find.text('\$45.000'), findsOneWidget);
  });

  testWidgets('this month filter keeps stock and hides older sales', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = await _seedStatsStore();
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/estadisticas');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stats-period-month')));
    await tester.pumpAndSettle();

    expect(find.text('7 unidades'), findsOneWidget);
    expect(find.text('\$105.000'), findsOneWidget);
    expect(find.text('1 unidad'), findsOneWidget);
    expect(find.text('\$15.000'), findsOneWidget);
    expect(find.text('3 unidades'), findsNothing);
    expect(find.text('\$45.000'), findsNothing);
  });

  testWidgets('administrator can open estadisticas', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInMemberSession(
      role: CompanyRole.administrator,
    );
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/estadisticas');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/estadisticas');
    expect(find.text('En prendas'), findsOneWidget);
    expect(find.text('0 unidades'), findsWidgets);
    expect(find.text('\$0'), findsWidgets);
  });
}
