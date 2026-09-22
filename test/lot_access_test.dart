import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/models/company_role.dart';
import 'package:store_app/models/lot.dart';
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

void main() {
  testWidgets('employee more page hides Lotes', (tester) async {
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

    expect(find.text('Lotes'), findsNothing);
    expect(find.text('Clientes'), findsOneWidget);
  });

  testWidgets('owner more page shows Lotes', (tester) async {
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

    expect(find.text('Lotes'), findsOneWidget);
  });

  testWidgets('employee is redirected away from /lotes', (tester) async {
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

    router.go('/lotes');
    await tester.pumpAndSettle();

    expect(find.text('Nuevo lote'), findsNothing);
    expect(router.state.uri.path, '/');
  });

  testWidgets('owner lots page shows investment figures', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertLot(testLot(name: 'Lote feria'));
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/lotes');
    await tester.pumpAndSettle();

    expect(find.text('Lote feria'), findsOneWidget);
    expect(find.text('11/09/2026'), findsOneWidget);
    expect(find.text('Precio del lote'), findsNothing);

    await tester.tap(find.text('Lote feria'));
    await tester.pumpAndSettle();

    expect(find.text('Precio del lote'), findsOneWidget);
    expect(find.text('Precio unitario'), findsOneWidget);
    expect(find.text('Cantidad en prendas'), findsOneWidget);
    expect(find.text('Vendidas'), findsOneWidget);
    expect(find.text('Sin vender'), findsOneWidget);
    expect(find.text('Reservadas'), findsOneWidget);
    expect(find.text('Total vendido'), findsOneWidget);
    expect(find.text('Total reservado'), findsOneWidget);
    expect(find.text('Total esperado'), findsOneWidget);
    expect(find.text('Recuperado'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Ganancia actual'), findsOneWidget);
    expect(find.text('Ganancia esperada'), findsOneWidget);
    expect(find.text('Vendido en otro medio'), findsNothing);
  });

  testWidgets('owner lots page shows other-channel sales when present', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertLot(testLot(name: 'Lote feria', soldElsewhere: 50000));
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/lotes');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lote feria'));
    await tester.pumpAndSettle();

    expect(find.text('Vendido en otro medio'), findsOneWidget);
    expect(find.text('Ganancia actual'), findsOneWidget);
    expect(find.text('Recuperado'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('new lot form starts on today and saves that date', (
    tester,
  ) async {
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

    router.go('/lotes');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-lot')));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final label = formatLotDay(DateTime(today.year, today.month, today.day));
    expect(find.text(label), findsOneWidget);
    expect(find.text('Fecha'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lot-date')));
    await tester.pumpAndSettle();
    expect(find.text('Fecha del lote'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text(label), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('lot-cost')), '40000');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('save-lot')));
    await tester.tap(find.byKey(const ValueKey('save-lot')));
    await tester.pumpAndSettle();

    expect(store.lots, hasLength(1));
    expect(store.lots.single.dateLabel, label);
    expect(find.text(label), findsOneWidget);
  });

  testWidgets('administrator lots page hides money stats', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertLot(testLot(name: 'Lote feria'));
    final session = await signedInMemberSession(
      role: CompanyRole.administrator,
    );
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/lotes');
    await tester.pumpAndSettle();

    expect(find.text('Lote feria'), findsOneWidget);
    expect(find.text('Nuevo lote'), findsOneWidget);
    expect(find.text('Precio del lote'), findsNothing);

    await tester.tap(find.text('Lote feria'));
    await tester.pumpAndSettle();

    expect(find.text('Lote feria'), findsOneWidget);
    expect(find.text('Precio del lote'), findsNothing);
    expect(find.text('Precio unitario'), findsNothing);
    expect(find.text('Cantidad en prendas'), findsNothing);
    expect(find.text('Vendidas'), findsNothing);
    expect(find.text('Total vendido'), findsNothing);
    expect(find.text('Ganancia actual'), findsNothing);
    expect(find.text('Ganancia esperada'), findsNothing);
    expect(find.text('Recuperado'), findsNothing);
  });
}
