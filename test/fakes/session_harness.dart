import 'package:store_app/data/session_store.dart';

import 'fake_auth_client.dart';
import 'fake_company_access.dart';

SessionStore createSessionStore({
  FakeAuthClient? auth,
  FakeCompanyAccess? access,
}) {
  return SessionStore(
    auth: auth ?? FakeAuthClient(),
    access: access ?? FakeCompanyAccess(),
  );
}

Future<SessionStore> signedInOwnerSession({
  String email = 'owner@moda.stock',
  String password = 'secret12',
  String displayName = 'Valeria Soto',
  String companyName = 'Moda Stock',
}) async {
  final session = createSessionStore()..start();
  await session.signUp(
    email: email,
    password: password,
    displayName: displayName,
    companyName: companyName,
  );
  return session;
}
