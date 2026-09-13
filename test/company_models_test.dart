import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/app_user.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/models/company_role.dart';
import 'package:store_app/models/email.dart';
import 'package:store_app/models/invitation.dart';
import 'package:store_app/models/membership.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 11);

  test('normalizeEmail trims and lowercases', () {
    expect(normalizeEmail('  Owner@Moda.Stock '), 'owner@moda.stock');
    expect(isValidEmail('owner@moda.stock'), isTrue);
    expect(isValidEmail('malo'), isFalse);
  });

  test('AppUser.fromMap stores a normalized email', () {
    final user = AppUser.fromMap('u1', {
      'email': '  Owner@Moda.Stock ',
      'displayName': ' Valeria ',
      'companyId': 'c1',
      'createdAt': createdAt,
    });
    expect(user.email, 'owner@moda.stock');
    expect(user.displayName, 'Valeria');
    expect(user.toMap()['email'], 'owner@moda.stock');
  });

  test('CompanyRole labels match owner, administrator and employee', () {
    expect(CompanyRole.owner.label, 'Propietario');
    expect(CompanyRole.administrator.label, 'Administrador');
    expect(CompanyRole.employee.label, 'Empleado');
    expect(CompanyRole.fromStorage('owner'), CompanyRole.owner);
    expect(CompanyRole.fromStorage('administrator'), CompanyRole.administrator);
    expect(CompanyRole.fromStorage('employee'), CompanyRole.employee);
    expect(CompanyRole.administrator.isAssignable, isTrue);
    expect(CompanyRole.employee.isAssignable, isTrue);
    expect(CompanyRole.owner.isAssignable, isFalse);
    expect(CompanyRole.owner.canViewTeam, isTrue);
    expect(CompanyRole.administrator.canViewTeam, isTrue);
    expect(CompanyRole.employee.canViewTeam, isFalse);
    expect(CompanyRole.owner.canDeleteProduct, isTrue);
    expect(CompanyRole.administrator.canDeleteProduct, isTrue);
    expect(CompanyRole.employee.canDeleteProduct, isFalse);
  });

  test('Invitation.fromMap reads pending status and path', () {
    final invitation = Invitation.fromMap('inv1', 'co1', {
      'email': '  Emp@Moda.Stock ',
      'role': 'employee',
      'status': 'pending',
      'invitedBy': 'u1',
      'createdAt': createdAt.toIso8601String(),
      'companyName': 'Moda Stock',
      'code': 'abcd23',
    });
    expect(invitation.email, 'emp@moda.stock');
    expect(invitation.isPending, isTrue);
    expect(invitation.path, '/invitar/co1/inv1');
    expect(invitation.code, 'ABCD23');
    expect(
      invitation.copyWith(status: InvitationStatus.accepted).isPending,
      isFalse,
    );
  });

  test('Membership.fromMap keeps the invitation id for employees', () {
    final member = Membership.fromMap('u2', 'co1', {
      'role': 'employee',
      'email': 'emp@moda.stock',
      'displayName': 'Ana',
      'joinedAt': createdAt,
      'invitationId': 'inv1',
    });
    expect(member.role, CompanyRole.employee);
    expect(member.invitationId, 'inv1');
    expect(member.toMap()['invitationId'], 'inv1');
  });

  test('Company.fromMap reads owner and name', () {
    final company = Company.fromMap('co1', {
      'name': ' Moda Stock ',
      'ownerId': 'u1',
      'createdAt': createdAt,
    });
    expect(company.name, 'Moda Stock');
    expect(company.ownerId, 'u1');
  });

  test('generateInviteCode uses six unambiguous characters', () {
    final code = generateInviteCode(Random(4));
    expect(code.length, inviteCodeLength);
    expect(code.split('').every(inviteCodeAlphabet.contains), isTrue);
    expect(normalizeInviteCode(' ab cd '), 'ABCD');
  });
}
