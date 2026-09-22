import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/routing/app_router.dart';

import 'fakes/fake_auth_client.dart';
import 'fakes/fake_company_access.dart';

void main() {
  testWidgets('reloading /pedido stays on pedidos once the session is ready', (
    tester,
  ) async {
    final auth = FakeAuthClient()..emitInitial = false;
    final session = SessionStore(auth: auth, access: FakeCompanyAccess())
      ..start();
    final store = AppStore();
    addTearDown(session.dispose);
    addTearDown(store.dispose);
    final router = createRouter(
      session,
      initialLocation: '/pedido',
      overridePlatformDefaultLocation: true,
    );

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, '/cargando');

    await session.signUp(
      email: 'owner@moda.stock',
      password: 'secret12',
      displayName: 'Valeria Soto',
      companyName: 'Moda Stock',
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/pedido');
    expect(find.text('Pedidos'), findsWidgets);
    expect(find.text('Todavía no hay pedidos abiertos.'), findsOneWidget);
  });
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
