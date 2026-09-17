import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/models/company_role.dart';
import 'package:store_app/routing/app_router.dart';

import 'fakes/fake_auth_client.dart';
import 'fakes/fake_company_access.dart';
import 'fakes/session_harness.dart';

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

void main() {
  testWidgets('employee more page hides Equipo', (tester) async {
    final store = AppStore();
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/mas');
    await tester.pumpAndSettle();

    expect(find.text('Equipo'), findsNothing);
    expect(find.text('Clientes'), findsOneWidget);
  });

  testWidgets('owner more page shows Equipo', (tester) async {
    final store = AppStore();
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/mas');
    await tester.pumpAndSettle();

    expect(find.text('Equipo'), findsOneWidget);
  });

  testWidgets('owner team page creates invitation and copies the link', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final store = AppStore();
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();
    router.go('/equipo');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'emp@moda.stock');
    await tester.tap(find.text('Crear invitación'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('emp@moda.stock'), findsOneWidget);
    expect(find.textContaining('Enlace copiado'), findsOneWidget);
  });

  testWidgets('owner team page keeps invitation if clipboard copy fails', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(
            code: 'copy_fail',
            message: 'Clipboard.setData failed.',
          );
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final store = AppStore();
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();
    router.go('/equipo');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'emp@moda.stock');
    await tester.tap(find.text('Crear invitación'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Enlace de invitación'), findsOneWidget);
    expect(
      find.text('No se pudo copiar. Seleccioná el texto y copialo.'),
      findsOneWidget,
    );
    expect(session.pendingInvitations, isNotEmpty);
    expect(session.pendingInvitations.first.email, 'emp@moda.stock');

    await tester.tap(find.text('Cerrar'));
    await tester.pump();
    expect(find.text('emp@moda.stock'), findsOneWidget);
  });

  testWidgets('employee cannot open Equipo', (tester) async {
    final store = AppStore();
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/equipo');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('Equipo'), findsNothing);
  });

  testWidgets('employee drawer hides Equipo', (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore();
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();
    router.go('/config');
    await tester.pumpAndSettle();

    expect(find.text('Equipo'), findsNothing);
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('Config'), findsWidgets);
  });

  testWidgets('owner drawer shows Equipo', (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore();
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();
    router.go('/config');
    await tester.pumpAndSettle();

    expect(find.text('Equipo'), findsOneWidget);
  });

  testWidgets('owner team page can remove an employee', (tester) async {
    final store = AppStore();
    final session = await signedInOwnerWithMember();
    addTearDown(session.dispose);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();
    router.go('/equipo');
    await tester.pumpAndSettle();

    expect(find.byTooltip('Eliminar'), findsOneWidget);
    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar del equipo'), findsOneWidget);
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(find.text('Ana Pérez'), findsNothing);
  });

  testWidgets('sign in reveals invite code field on demand', (tester) async {
    final store = AppStore();
    final session = createSessionStore()..start();
    addTearDown(session.dispose);
    await session.initialized;
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Código de invitación'), findsNothing);
    expect(find.text('¿Tenés un código de invitación?'), findsOneWidget);

    await tester.tap(find.text('¿Tenés un código de invitación?'));
    await tester.pumpAndSettle();

    expect(find.text('¿Tenés un código de invitación?'), findsNothing);
    expect(find.text('Código de invitación'), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();

    expect(find.text('Moda Stock'), findsOneWidget);
    expect(find.text('Gestioná indumentaria y calzado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login form stays up with a keyboard inset', (tester) async {
    tester.view.physicalSize = const Size(400, 720);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final store = AppStore();
    final session = createSessionStore()..start();
    addTearDown(session.dispose);
    await session.initialized;
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    final safeArea = tester.widget<SafeArea>(find.byType(SafeArea).first);
    expect(safeArea.maintainBottomViewPadding, isTrue);
    await tester.enterText(find.byType(TextFormField), 'owner@moda.stock');
    await tester.pump();
    expect(find.text('owner@moda.stock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign in validates email format', (tester) async {
    final store = AppStore();
    final session = createSessionStore()..start();
    addTearDown(session.dispose);
    await session.initialized;
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'malo');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresá un email válido.'), findsOneWidget);
    expect(session.hasIdentity, isFalse);
  });

  testWidgets('sign in opens stock', (tester) async {
    final store = AppStore();
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    await session.signOut();

    final router = createRouter(session);
    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'owner@moda.stock');
    await tester.enterText(find.byType(TextField).at(1), 'secret12');
    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pumpAndSettle();

    expect(session.isSignedIn, isTrue);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('Stock'), findsWidgets);
  });

  testWidgets('removed member lands on join page', (tester) async {
    final store = AppStore();
    final auth = FakeAuthClient();
    final access = FakeCompanyAccess();
    final session = SessionStore(auth: auth, access: access)..start();
    addTearDown(session.dispose);

    await session.signUp(
      email: 'owner@moda.stock',
      password: 'secret12',
      displayName: 'Valeria Soto',
      companyName: 'Moda Stock',
    );
    final invitation = await session.inviteEmployee('emp@moda.stock');
    await session.signOut();
    await session.signUp(
      email: 'emp@moda.stock',
      password: 'secret12',
      displayName: 'Ana Pérez',
      inviteCompanyId: invitation.companyId,
      inviteId: invitation.id,
    );
    final employeeUid = session.user!.id;
    await session.signOut();
    await session.signIn(email: 'owner@moda.stock', password: 'secret12');
    await session.removeMember(employeeUid);
    await session.signOut();
    await session.signIn(email: 'emp@moda.stock', password: 'secret12');

    final router = createRouter(session);
    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/unirse');
    expect(find.text('Código de invitación'), findsOneWidget);
    expect(find.text('Crear empresa'), findsOneWidget);
  });

  testWidgets('removed member can sign out from join page', (tester) async {
    final store = AppStore();
    final auth = FakeAuthClient();
    final access = FakeCompanyAccess();
    final session = SessionStore(auth: auth, access: access)..start();
    addTearDown(session.dispose);

    await session.signUp(
      email: 'owner@moda.stock',
      password: 'secret12',
      displayName: 'Valeria Soto',
      companyName: 'Moda Stock',
    );
    final invitation = await session.inviteEmployee('emp@moda.stock');
    await session.signOut();
    await session.signUp(
      email: 'emp@moda.stock',
      password: 'secret12',
      displayName: 'Ana Pérez',
      inviteCompanyId: invitation.companyId,
      inviteId: invitation.id,
    );
    final employeeUid = session.user!.id;
    await session.signOut();
    await session.signIn(email: 'owner@moda.stock', password: 'secret12');
    await session.removeMember(employeeUid);
    await session.signOut();
    await session.signIn(email: 'emp@moda.stock', password: 'secret12');

    final router = createRouter(session);
    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cerrar sesión'), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(session.hasIdentity, isFalse);
    expect(session.needsCompany, isFalse);
    expect(router.routeInformationProvider.value.uri.path, '/ingresar');
    expect(find.text('Ingresar'), findsWidgets);
  });
}
