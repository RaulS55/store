import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/models/company_role.dart';
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
  testWidgets('employee more page hides Montones', (tester) async {
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

    expect(find.text('Montones'), findsNothing);
    expect(find.text('Clientes'), findsOneWidget);
  });

  testWidgets('owner more page shows Montones', (tester) async {
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

    expect(find.text('Montones'), findsOneWidget);
  });

  testWidgets('employee is redirected away from /montones', (tester) async {
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

    router.go('/montones');
    await tester.pumpAndSettle();

    expect(find.text('Nuevo montón'), findsNothing);
    expect(router.state.uri.path, '/');
  });

  testWidgets('owner lots page shows recovered and remaining to recover', (
    tester,
  ) async {
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

    router.go('/montones');
    await tester.pumpAndSettle();

    expect(find.text('Lote feria'), findsOneWidget);
    expect(find.text('Costo'), findsOneWidget);
    expect(find.text('Suma prendas'), findsOneWidget);
    expect(find.text('Recuperado'), findsOneWidget);
    expect(find.text('Falta recuperar'), findsOneWidget);
    expect(find.text('Ganancia'), findsNothing);
    expect(find.text('Capital en ropa'), findsNothing);
  });

  testWidgets('owner lots page shows profit when recovered exceeds cost', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertLot(
      testLot(name: 'Lote feria', soldElsewhere: 50000),
    );
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/montones');
    await tester.pumpAndSettle();

    expect(find.text('Ganancia'), findsOneWidget);
    expect(find.text('Falta recuperar'), findsNothing);
    expect(find.text('Capital en ropa'), findsNothing);
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

    router.go('/montones');
    await tester.pumpAndSettle();

    expect(find.text('Lote feria'), findsOneWidget);
    expect(find.text('Nuevo montón'), findsOneWidget);
    expect(find.text('Costo'), findsNothing);
    expect(find.text('Suma prendas'), findsNothing);
    expect(find.text('Recuperado'), findsNothing);
    expect(find.text('Ganancia'), findsNothing);
    expect(find.text('Falta recuperar'), findsNothing);
    expect(find.text('Capital en ropa'), findsNothing);
  });
}
