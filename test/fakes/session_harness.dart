import 'package:store_app/data/session_store.dart';
import 'package:store_app/models/company_role.dart';

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

Future<SessionStore> signedInMemberSession({
  required CompanyRole role,
  String ownerEmail = 'owner@moda.stock',
  String memberEmail = 'emp@moda.stock',
  String password = 'secret12',
}) async {
  final session = createSessionStore()..start();
  await session.signUp(
    email: ownerEmail,
    password: password,
    displayName: 'Valeria Soto',
    companyName: 'Moda Stock',
  );
  final invitation = await session.inviteEmployee(memberEmail, role: role);
  await session.signOut();
  await session.signUp(
    email: memberEmail,
    password: password,
    displayName: 'Ana Pérez',
    inviteCompanyId: invitation.companyId,
    inviteId: invitation.id,
  );
  return session;
}

Future<SessionStore> signedInOwnerWithMember({
  CompanyRole role = CompanyRole.employee,
  String ownerEmail = 'owner@moda.stock',
  String memberEmail = 'emp@moda.stock',
  String password = 'secret12',
}) async {
  final session = createSessionStore()..start();
  await session.signUp(
    email: ownerEmail,
    password: password,
    displayName: 'Valeria Soto',
    companyName: 'Moda Stock',
  );
  final invitation = await session.inviteEmployee(memberEmail, role: role);
  await session.signOut();
  await session.signUp(
    email: memberEmail,
    password: password,
    displayName: 'Ana Pérez',
    inviteCompanyId: invitation.companyId,
    inviteId: invitation.id,
  );
  await session.signOut();
  await session.signIn(email: ownerEmail, password: password);
  await session.loadTeam();
  return session;
}
