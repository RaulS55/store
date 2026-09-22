import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/routing/app_router.dart';

import 'fakes/fake_auth_client.dart';
import 'fakes/fake_company_access.dart';
import 'fakes/session_harness.dart';

Future<void> _waitReady(SessionStore session) async {
  for (var i = 0; i < 20 && !session.isReady; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('catalog paths stay public without signing in', () async {
    final session = createSessionStore()..start();
    addTearDown(session.dispose);
    await _waitReady(session);
    expect(session.isReady, isTrue);
    expect(session.isSignedIn, isFalse);

    expect(sessionRedirect(session, '/pedido'), '/ingresar');
    expect(sessionRedirect(session, '/'), '/ingresar');
    expect(sessionRedirect(session, '/catalogo/co1'), isNull);
    expect(sessionRedirect(session, '/catalogo/co1/pedido'), isNull);
    expect(sessionRedirect(session, '/catalogo/co1/producto/p1'), isNull);
  });

  test('catalog paths stay reachable when the owner is signed in', () async {
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);

    expect(sessionRedirect(session, '/ingresar'), '/');
    expect(sessionRedirect(session, '/catalogo/${session.companyId}'), isNull);
    expect(
      sessionRedirect(session, '/catalogo/${session.companyId}/pedido'),
      isNull,
    );
  });

  test('reload on pedidos resumes after the session is ready', () async {
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);

    expect(sessionRedirect(session, '/cargando', resume: '/pedido'), '/pedido');
    expect(
      sessionRedirect(session, '/cargando', resume: '/pedido/o1'),
      '/pedido/o1',
    );
    expect(
      sessionRedirect(session, '/cargando', resume: '/pedido/o1/facturar'),
      '/pedido/o1/facturar',
    );
    expect(sessionRedirect(session, '/cargando'), '/');
    expect(sessionRedirect(session, '/cargando', resume: '/ingresar'), '/');
    expect(
      sessionRedirect(session, '/cargando', resume: 'https://evil.test'),
      '/',
    );
    expect(sessionRedirect(session, '/pedido'), isNull);
  });

  test('catalog is allowed before the session is ready', () {
    final session = createSessionStore();
    addTearDown(session.dispose);
    expect(session.isReady, isFalse);
    expect(sessionRedirect(session, '/'), '/cargando');
    expect(sessionRedirect(session, '/catalogo/co1'), isNull);
  });

  test('catalog stays public if auth never emits', () async {
    final auth = FakeAuthClient()..emitInitial = false;
    final session = SessionStore(
      auth: auth,
      access: FakeCompanyAccess(),
      authReadyTimeout: const Duration(milliseconds: 20),
    )..start();
    addTearDown(session.dispose);
    expect(sessionRedirect(session, '/catalogo/co1'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(session.isReady, isTrue);
    expect(session.isSignedIn, isFalse);
    expect(sessionRedirect(session, '/catalogo/co1'), isNull);
    expect(sessionRedirect(session, '/'), '/ingresar');
  });
}
