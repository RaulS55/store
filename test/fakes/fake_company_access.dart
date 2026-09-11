import 'package:store_app/data/company_access.dart';
import 'package:store_app/data/session_exception.dart';
import 'package:store_app/models/app_user.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/models/company_role.dart';
import 'package:store_app/models/email.dart';
import 'package:store_app/models/invitation.dart';
import 'package:store_app/models/membership.dart';

class FakeCompanyAccess implements CompanyAccess {
  final users = <String, AppUser>{};
  final companies = <String, Company>{};
  final members = <String, Map<String, Membership>>{};
  final invitations = <String, Map<String, Invitation>>{};
  var _seq = 0;

  String _id() => 'id-${++_seq}';

  DateTime get _now => DateTime.utc(2026, 9, 11);

  @override
  Future<AppUser?> getUser(String uid) async => users[uid];

  @override
  Future<Company?> getCompany(String companyId) async => companies[companyId];

  @override
  Future<Company?> findCompanyByOwner(String uid) async {
    for (final company in companies.values) {
      if (company.ownerId == uid) return company;
    }
    return null;
  }

  @override
  Future<Membership?> getMembership(String companyId, String uid) async {
    return members[companyId]?[uid];
  }

  @override
  Future<List<Membership>> listMembers(String companyId) async {
    final list = [...?members[companyId]?.values];
    list.sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
  }

  @override
  Future<List<Invitation>> listInvitations(String companyId) async {
    final list = [...?invitations[companyId]?.values];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Invitation?> getInvitation(
    String companyId,
    String invitationId,
  ) async {
    return invitations[companyId]?[invitationId];
  }

  @override
  Future<Invitation?> findPendingInvitationByEmail(String email) async {
    final normalized = normalizeEmail(email);
    for (final byCompany in invitations.values) {
      for (final invitation in byCompany.values) {
        if (invitation.isPending && invitation.email == normalized) {
          return invitation;
        }
      }
    }
    return null;
  }

  @override
  Future<void> createOwnerCompany({
    required String uid,
    required String email,
    required String displayName,
    required String companyName,
  }) async {
    final name = companyName.trim();
    if (name.isEmpty) {
      throw const SessionException('Ingresá el nombre de la empresa.');
    }
    final companyId = _id();
    companies[companyId] = Company(
      id: companyId,
      name: name,
      ownerId: uid,
      createdAt: _now,
    );
    await ensureOwnerProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      company: companies[companyId]!,
    );
  }

  @override
  Future<void> ensureOwnerProfile({
    required String uid,
    required String email,
    required String displayName,
    required Company company,
  }) async {
    final membership = Membership(
      uid: uid,
      companyId: company.id,
      role: CompanyRole.owner,
      email: normalizeEmail(email),
      displayName: displayName.trim(),
      joinedAt: _now,
    );
    members.putIfAbsent(company.id, () => {})[uid] = membership;
    users[uid] = AppUser(
      id: uid,
      email: normalizeEmail(email),
      displayName: displayName.trim(),
      companyId: company.id,
      createdAt: _now,
    );
  }

  @override
  Future<Invitation> createInvitation({
    required String companyId,
    required String companyName,
    required String email,
    required String invitedBy,
    required CompanyRole role,
  }) async {
    if (!isValidEmail(email)) {
      throw const SessionException('Ingresá un email válido.');
    }
    if (!role.isAssignable) {
      throw const SessionException('Elegí Administrador o Empleado.');
    }
    final normalized = normalizeEmail(email);
    final companyMembers = members[companyId] ?? {};
    if (companyMembers.values.any((member) => member.email == normalized)) {
      throw const SessionException('Esa persona ya es miembro.');
    }
    final companyInvites = invitations.putIfAbsent(companyId, () => {});
    if (companyInvites.values.any(
      (invite) => invite.isPending && invite.email == normalized,
    )) {
      throw const SessionException(
        'Ya hay una invitación pendiente para ese email.',
      );
    }
    final invitation = Invitation(
      id: _id(),
      companyId: companyId,
      email: normalized,
      role: role,
      status: InvitationStatus.pending,
      invitedBy: invitedBy,
      createdAt: _now,
      companyName: companyName.trim(),
    );
    companyInvites[invitation.id] = invitation;
    return invitation;
  }

  @override
  Future<void> acceptInvitation({
    required String uid,
    required String email,
    required String displayName,
    required String companyId,
    required String invitationId,
  }) async {
    final invitation = invitations[companyId]?[invitationId];
    if (invitation == null) {
      throw const SessionException('La invitación no existe.');
    }
    if (!invitation.isPending) {
      throw const SessionException('Esta invitación ya no está disponible.');
    }
    final normalized = normalizeEmail(email);
    if (invitation.email != normalized) {
      throw const SessionException('Esta invitación es para otro email.');
    }
    final existing = users[uid];
    if (existing != null && existing.companyId.isNotEmpty) {
      throw const SessionException('Ya pertenecés a una empresa.');
    }
    invitations[companyId]![invitationId] = invitation.copyWith(
      status: InvitationStatus.accepted,
    );
    members.putIfAbsent(companyId, () => {})[uid] = Membership(
      uid: uid,
      companyId: companyId,
      role: invitation.role,
      email: normalized,
      displayName: displayName.trim(),
      joinedAt: _now,
      invitationId: invitationId,
    );
    users[uid] = AppUser(
      id: uid,
      email: normalized,
      displayName: displayName.trim(),
      companyId: companyId,
      createdAt: _now,
    );
  }

  @override
  Future<void> revokeInvitation({
    required String companyId,
    required String invitationId,
  }) async {
    final invitation = invitations[companyId]?[invitationId];
    if (invitation == null) {
      throw const SessionException('La invitación no existe.');
    }
    if (!invitation.isPending) {
      throw const SessionException('Esta invitación ya no está pendiente.');
    }
    invitations[companyId]![invitationId] = invitation.copyWith(
      status: InvitationStatus.revoked,
    );
  }
}
