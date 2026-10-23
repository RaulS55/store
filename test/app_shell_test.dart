import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/widgets/app_shell.dart';

import 'fakes/session_harness.dart';

void main() {
  testWidgets('wide nav keeps the selected tile color visible', (tester) async {
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            for (final path in [
              '/',
              '/pedido',
              '/producto/nuevo',
              '/clientes',
              '/lotes',
              '/estadisticas',
              '/equipo',
              '/config',
            ])
              GoRoute(
                path: path,
                builder: (context, state) => const SizedBox.shrink(),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stock'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
