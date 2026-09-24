import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/features/order/orders_page.dart';
import 'package:store_app/routing/app_router.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/session_harness.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _pageApp(AppStore store) {
  return ChangeNotifierProvider.value(
    value: store,
    child: const MaterialApp(home: Scaffold(body: OrdersPage())),
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

Future<void> _openClosedTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('orders-tab-closed')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('orders page shows closed orders in a related tab', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);

    await tester.pumpWidget(_pageApp(store));
    await tester.pump();

    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.byKey(const ValueKey('orders-tab-open')), findsOneWidget);
    expect(find.byKey(const ValueKey('orders-tab-closed')), findsOneWidget);
    expect(find.text('Todavía no hay pedidos abiertos.'), findsOneWidget);
    expect(find.text('Cerrados'), findsOneWidget);

    await _openClosedTab(tester);

    expect(find.byKey(ValueKey('closed-order-${order.id}')), findsOneWidget);
    expect(find.text(order.customer.name), findsOneWidget);
    expect(find.textContaining(order.orderNumber), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);
  });

  testWidgets('orders page switches between open and closed orders', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final closed = await seedTestOrder(store);
    expect(store.closeOrder(closed.id), isTrue);
    final open = await seedTestOrder(store);

    await tester.pumpWidget(_pageApp(store));
    await tester.pump();

    expect(find.text('Abiertos (1)'), findsOneWidget);
    expect(find.text('Cerrados'), findsOneWidget);
    expect(find.textContaining(open.orderNumber), findsOneWidget);

    await _openClosedTab(tester);

    expect(find.byKey(ValueKey('closed-order-${closed.id}')), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);
  });

  testWidgets('tapping a closed order opens the billing view', (tester) async {
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);
    final router = createRouter(session);

    await tester.pumpWidget(
      _routerApp(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/pedido');
    await tester.pumpAndSettle();
    await _openClosedTab(tester);
    await tester.ensureVisible(
      find.byKey(ValueKey('closed-order-${order.id}')),
    );
    await tester.tap(find.byKey(ValueKey('closed-order-${order.id}')));
    await tester.pumpAndSettle();

    expect(find.text('RESUMEN DE FACTURA'), findsOneWidget);
    expect(find.text('Total a facturar'), findsOneWidget);
  });

  testWidgets('more page no longer lists closed orders', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);
    final router = createRouter(session);

    await tester.pumpWidget(
      _routerApp(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/mas');
    await tester.pumpAndSettle();

    expect(find.text('Pedidos cerrados'), findsNothing);
    expect(find.text(order.orderNumber), findsNothing);
  });
}
