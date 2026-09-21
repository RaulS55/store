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
    expect(CompanyRole.owner.canDeleteCustomer, isTrue);
    expect(CompanyRole.administrator.canDeleteCustomer, isTrue);
    expect(CompanyRole.employee.canDeleteCustomer, isFalse);
    expect(CompanyRole.owner.canEditCompanySettings, isTrue);
    expect(CompanyRole.administrator.canEditCompanySettings, isTrue);
    expect(CompanyRole.employee.canEditCompanySettings, isFalse);
    expect(CompanyRole.owner.canManageLots, isTrue);
    expect(CompanyRole.administrator.canManageLots, isTrue);
    expect(CompanyRole.employee.canManageLots, isFalse);
    expect(CompanyRole.owner.canViewLotStats, isTrue);
    expect(CompanyRole.administrator.canViewLotStats, isFalse);
    expect(CompanyRole.employee.canViewLotStats, isFalse);
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

  test('Company.fromMap reads owner, name and rubro', () {
    final company = Company.fromMap('co1', {
      'name': ' Moda Stock ',
      'ownerId': 'u1',
      'createdAt': createdAt,
    });
    expect(company.name, 'Moda Stock');
    expect(company.ownerId, 'u1');
    expect(company.rubro, CompanyRubro.ambos);
    expect(company.phone, isNull);
    expect(company.toMap()['rubro'], 'ambos');
    expect(company.toMap()['phone'], isNull);

    final withPhone = Company.fromMap('co1', {
      'name': 'Moda Stock',
      'ownerId': 'u1',
      'createdAt': createdAt,
      'phone': ' +54 9 11 4555-0101 ',
    });
    expect(withPhone.phone, '+54 9 11 4555-0101');
    expect(withPhone.whatsappDigits, '5491145550101');
    expect(withPhone.copyWith(phone: null).phone, isNull);

    final branded = Company.fromMap('co1', {
      'name': 'Moda Stock',
      'ownerId': 'u1',
      'createdAt': createdAt,
      'logoUrl': ' https://cdn.moda.stock/logo.jpg ',
      'instagram': ' @moda.stock ',
      'tiktok': 'moda.stock',
      'facebook': 'https://www.facebook.com/modastock',
    });
    expect(branded.logoUrl, 'https://cdn.moda.stock/logo.jpg');
    expect(branded.instagram, '@moda.stock');
    expect(branded.tiktok, 'moda.stock');
    expect(branded.facebook, 'https://www.facebook.com/modastock');
    expect(branded.instagramUrl, 'https://www.instagram.com/moda.stock');
    expect(branded.tiktokUrl, 'https://www.tiktok.com/@moda.stock');
    expect(branded.facebookUrl, 'https://www.facebook.com/modastock');
    expect(branded.copyWith(logoUrl: null).logoUrl, isNull);
    expect(branded.toMap()['instagram'], '@moda.stock');

    final footwear = Company.fromMap('co2', {
      'name': 'Zapas',
      'ownerId': 'u1',
      'createdAt': createdAt,
      'rubro': 'calzado',
    });
    expect(footwear.rubro, CompanyRubro.calzado);
    expect(
      footwear.copyWith(rubro: CompanyRubro.ropa).rubro,
      CompanyRubro.ropa,
    );
  });

  test('generateInviteCode uses six unambiguous characters', () {
    final code = generateInviteCode(Random(4));
    expect(code.length, inviteCodeLength);
    expect(code.split('').every(inviteCodeAlphabet.contains), isTrue);
    expect(socialProfileUrl(null, host: 'www.instagram.com'), isNull);
    expect(
      socialProfileUrl('@moda', host: 'www.instagram.com'),
      'https://www.instagram.com/moda',
    );
    expect(
      socialProfileUrl('instagram.com/@moda', host: 'www.instagram.com'),
      'https://www.instagram.com/moda',
    );
    expect(
      socialProfileUrl('https://www.tiktok.com/@moda', host: 'www.tiktok.com'),
      'https://www.tiktok.com/@moda',
    );
    expect(
      socialProfileUrl('moda', host: 'www.tiktok.com', atHandle: true),
      'https://www.tiktok.com/@moda',
    );
  });
}
