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
    expect(session.canDeleteProduct, isTrue);
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

  test('employee cannot view team and does not list invitations', () async {
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

    access.listInvitationsCalls = 0;
    await session.loadTeam();

    expect(session.canViewTeam, isFalse);
    expect(session.canDeleteProduct, isFalse);
    expect(session.members, isEmpty);
    expect(session.invitations, isEmpty);
    expect(access.listInvitationsCalls, 0);
  });

  test('administrator can view team members but not invitations', () async {
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
    await session.signOut();
    await session.signUp(
      email: 'admin@moda.stock',
      password: 'secret12',
      displayName: 'Ana Pérez',
      inviteCompanyId: invitation.companyId,
      inviteId: invitation.id,
    );

    access.listInvitationsCalls = 0;
    await session.loadTeam();

    expect(session.canViewTeam, isTrue);
    expect(session.canDeleteProduct, isTrue);
    expect(session.isOwner, isFalse);
    expect(session.members, isNotEmpty);
    expect(session.invitations, isEmpty);
    expect(access.listInvitationsCalls, 0);
  });

  test(
    'owner can remove an employee and that account needs a company',
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
        inviteCompanyId: invitation.companyId,
        inviteId: invitation.id,
      );
      final employeeUid = session.user!.id;
      await session.signOut();
      await session.signIn(email: 'owner@moda.stock', password: 'secret12');
      await session.removeMember(employeeUid);

      expect(
        session.members.any((member) => member.uid == employeeUid),
        isFalse,
      );
      expect(access.users[employeeUid]?.companyId, isEmpty);

      await session.signOut();
      await session.signIn(email: 'emp@moda.stock', password: 'secret12');
      expect(session.isSignedIn, isFalse);
      expect(session.needsCompany, isTrue);
      expect(session.hasIdentity, isTrue);
    },
  );

  test('removed employee can join another company with a code', () async {
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
    final firstInvite = await session.inviteEmployee('emp@moda.stock');
    await session.signOut();
    await session.signUp(
      email: 'emp@moda.stock',
      password: 'secret12',
      displayName: 'Ana Pérez',
      inviteCompanyId: firstInvite.companyId,
      inviteId: firstInvite.id,
    );
    final employeeUid = session.user!.id;
    await session.signOut();
    await session.signIn(email: 'owner@moda.stock', password: 'secret12');
    await session.removeMember(employeeUid);
    await session.signOut();

    await session.signUp(
      email: 'otro@moda.stock',
      password: 'secret12',
      displayName: 'Bruno',
      companyName: 'Otra',
    );
    final secondInvite = await session.inviteEmployee('emp@moda.stock');
    expect(secondInvite.code, isNotEmpty);
    await session.signOut();
    await session.signIn(
      email: 'emp@moda.stock',
      password: 'secret12',
      inviteCode: secondInvite.code,
    );

    expect(session.isSignedIn, isTrue);
    expect(session.membership?.role, CompanyRole.employee);
    expect(session.company?.name, 'Otra');
  });

  test('removed employee can create a company', () async {
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
    await session.createOwnedCompany('Taller Ana');

    expect(session.isSignedIn, isTrue);
    expect(session.isOwner, isTrue);
    expect(session.company?.name, 'Taller Ana');
  });

  test('owner cannot remove the owner', () async {
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);

    await expectLater(
      session.removeMember(session.user!.id),
      throwsA(
        isA<SessionException>().having(
          (error) => error.message,
          'message',
          'No se puede sacar al propietario.',
        ),
      ),
    );
  });

  test('employee cannot remove a member', () async {
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);

    await expectLater(
      session.removeMember('uid-1'),
      throwsA(isA<SessionException>()),
    );
  });

  test('orphan companyId without membership lands on join', () async {
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
    final companyId = invitation.companyId;
    await session.signOut();

    access.members[companyId]?.remove(employeeUid);

    await session.signIn(email: 'emp@moda.stock', password: 'secret12');

    expect(session.isSignedIn, isFalse);
    expect(session.needsCompany, isTrue);
    expect(session.user?.id, employeeUid);
    expect(session.user?.companyId, isEmpty);
    expect(access.users[employeeUid]?.companyId, isEmpty);
  });

  test('sign up with a valid invite code joins as that role', () async {
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
    await session.signOut();
    await session.signUp(
      email: 'admin@moda.stock',
      password: 'secret12',
      displayName: 'Ana Pérez',
      inviteCode: invitation.code,
    );

    expect(session.membership?.role, CompanyRole.administrator);
    expect(session.companyId, invitation.companyId);
  });

  test('invite code for another email is rejected', () async {
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
        inviteCode: invitation.code,
      ),
      throwsA(
        isA<SessionException>().having(
          (error) => error.message,
          'message',
          'El código no es válido.',
        ),
      ),
    );
  });
}
