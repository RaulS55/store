import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/session_exception.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/models/company_role.dart';

import 'fakes/fake_auth_client.dart';
import 'fakes/fake_company_access.dart';
import 'fakes/session_harness.dart';

void main() {
  test('sign up without invite creates an owner company', () async {
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    expect(session.isSignedIn, isTrue);
    expect(session.isOwner, isTrue);
    expect(session.user?.email, 'owner@moda.stock');
    expect(session.company?.name, 'Moda Stock');
    expect(session.membership?.role, CompanyRole.owner);
    expect(session.companyId, isNotEmpty);
  });

  test('owner invite then employee accept joins the same company', () async {
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
    expect(invitation.isPending, isTrue);
    expect(invitation.email, 'emp@moda.stock');
    expect(invitation.role, CompanyRole.employee);
    final companyId = session.companyId;

    await session.signOut();
    await session.signUp(
      email: 'emp@moda.stock',
      password: 'secret12',
      displayName: 'Ana Pérez',
      inviteCompanyId: invitation.companyId,
      inviteId: invitation.id,
    );

    expect(session.isOwner, isFalse);
    expect(session.membership?.role, CompanyRole.employee);
    expect(session.companyId, companyId);
    expect(session.company?.name, 'Moda Stock');
  });

  test('owner invite as administrator keeps that role after accept', () async {
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
    final invitation = await session.inviteEmployee(
      'admin@moda.stock',
      role: CompanyRole.administrator,
    );
    expect(invitation.role, CompanyRole.administrator);

    await session.signOut();
    await session.signUp(
      email: 'admin@moda.stock',
      password: 'secret12',
      displayName: 'Ana Pérez',
      inviteCompanyId: invitation.companyId,
      inviteId: invitation.id,
    );

    expect(session.isOwner, isFalse);
    expect(session.membership?.role, CompanyRole.administrator);
    expect(session.membership?.role.label, 'Administrador');
  });

  test(
    'pending invite by email joins as employee without creating a company',
    () async {
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
        companyName: 'Otra Empresa',
      );

      expect(session.companyId, invitation.companyId);
      expect(session.company?.name, 'Moda Stock');
      expect(session.membership?.role, CompanyRole.employee);
    },
  );

  test('accept fails when the user already belongs to a company', () async {
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
      email: 'otro@moda.stock',
      password: 'secret12',
      displayName: 'Otro',
      companyName: 'Otra',
    );

    await expectLater(
      session.acceptInvitation(invitation.companyId, invitation.id),
      throwsA(
        isA<SessionException>().having(
          (error) => error.message,
          'message',
          'Ya pertenecés a una empresa.',
        ),
      ),
    );
  });

  test('sign up with a mismatched invite email is rejected', () async {
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

    await expectLater(
      session.signUp(
        email: 'otro@moda.stock',
        password: 'secret12',
        displayName: 'Otro',
        inviteCompanyId: invitation.companyId,
        inviteId: invitation.id,
      ),
      throwsA(
        isA<SessionException>().having(
          (error) => error.message,
          'message',
          'Esta invitación es para otro email.',
        ),
      ),
    );
  });

  test('users of different companies do not share companyId', () async {
    final auth = FakeAuthClient();
    final access = FakeCompanyAccess();
    final session = SessionStore(auth: auth, access: access)..start();
    addTearDown(session.dispose);

    await session.signUp(
      email: 'a@moda.stock',
      password: 'secret12',
      displayName: 'Ana',
      companyName: 'Empresa A',
    );
    final companyA = session.companyId;
    await session.signOut();
    await session.signUp(
      email: 'b@moda.stock',
      password: 'secret12',
      displayName: 'Bruno',
      companyName: 'Empresa B',
    );

    expect(session.company?.name, 'Empresa B');
    expect(session.companyId, isNot(companyA));
    expect(
      access.users['uid-1']?.companyId,
      isNot(access.users['uid-2']?.companyId),
    );
    expect(
      access.members[access.users['uid-1']!.companyId]!.containsKey('uid-2'),
      isFalse,
    );
    expect(
      access.members[access.users['uid-2']!.companyId]!.containsKey('uid-1'),
      isFalse,
    );
  });

  test('employee cannot invite', () async {
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

    expect(
      () => session.inviteEmployee('otro@moda.stock'),
      throwsA(isA<SessionException>()),
    );
  });
}
