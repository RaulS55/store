import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/company.dart';
import '../models/company_role.dart';
import '../models/email.dart';
import '../models/invitation.dart';
import '../models/membership.dart';
import 'company_access.dart';
import 'firestore_query.dart';
import 'session_exception.dart';

class FirestoreCompanyAccess implements CompanyAccess {
  FirestoreCompanyAccess({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users {
    return _db.collection('users');
  }

  CollectionReference<Map<String, dynamic>> get _companies {
    return _db.collection('companies');
  }

  CollectionReference<Map<String, dynamic>> _members(String companyId) {
    return _companies.doc(companyId).collection('members');
  }

  CollectionReference<Map<String, dynamic>> _invitations(String companyId) {
    return _companies.doc(companyId).collection('invitations');
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return AppUser.fromMap(snap.id, snap.data()!);
  }

  @override
  Future<Company?> getCompany(String companyId) async {
    try {
      final snap = await _companies.doc(companyId).get();
      if (!snap.exists || snap.data() == null) return null;
      return Company.fromMap(snap.id, snap.data()!);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return null;
      rethrow;
    }
  }

  @override
  Future<Company?> findCompanyByOwner(String uid) async {
    try {
      final docs = await getFirestoreDocs(
        collection: _companies,
        filters: [FirestoreFilter.equal('ownerId', uid)],
        limit: 1,
      );
      if (docs.isEmpty) return null;
      return Company.fromMap(docs.first.id, docs.first.data);
    } catch (error) {
      if (isFirestorePermissionDenied(error)) return null;
      rethrow;
    }
  }

  @override
  Future<Membership?> getMembership(String companyId, String uid) async {
    final snap = await _members(companyId).doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return Membership.fromMap(snap.id, companyId, snap.data()!);
  }

  @override
  Future<List<Membership>> listMembers(String companyId) async {
    final docs = await getFirestoreDocs(collection: _members(companyId));
    final members = [
      for (final doc in docs) Membership.fromMap(doc.id, companyId, doc.data),
    ];
    members.sort((a, b) => a.displayName.compareTo(b.displayName));
    return members;
  }

  @override
  Future<List<Invitation>> listInvitations(String companyId) async {
    final docs = await getFirestoreDocs(collection: _invitations(companyId));
    final invitations = [
      for (final doc in docs) Invitation.fromMap(doc.id, companyId, doc.data),
    ];
    invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return invitations;
  }

  @override
  Future<Invitation?> getInvitation(
    String companyId,
    String invitationId,
  ) async {
    final snap = await _invitations(companyId).doc(invitationId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Invitation.fromMap(snap.id, companyId, snap.data()!);
  }

  @override
  Future<Invitation?> findPendingInvitationByEmail(String email) async {
    try {
      final docs = await getFirestoreDocs(
        firestore: _db,
        collectionGroup: 'invitations',
        filters: [
          FirestoreFilter.equal('email', normalizeEmail(email)),
          FirestoreFilter.equal('status', InvitationStatus.pending.name),
        ],
        limit: 1,
      );
      if (docs.isEmpty) return null;
      final doc = docs.first;
      final companyId = doc.parentDocumentId;
      if (companyId == null) return null;
      return Invitation.fromMap(doc.id, companyId, doc.data);
    } catch (error) {
      if (isFirestorePermissionDenied(error)) return null;
      rethrow;
    }
  }

  @override
  Future<Invitation?> findPendingInvitationByCode(
    String email,
    String code,
  ) async {
    final normalizedCode = normalizeInviteCode(code);
    if (normalizedCode.length != inviteCodeLength) return null;
    try {
      final docs = await getFirestoreDocs(
        firestore: _db,
        collectionGroup: 'invitations',
        filters: [
          FirestoreFilter.equal('code', normalizedCode),
          FirestoreFilter.equal('email', normalizeEmail(email)),
          FirestoreFilter.equal('status', InvitationStatus.pending.name),
        ],
        limit: 1,
      );
      if (docs.isEmpty) return null;
      final doc = docs.first;
      final companyId = doc.parentDocumentId;
      if (companyId == null) return null;
      return Invitation.fromMap(doc.id, companyId, doc.data);
    } catch (error) {
      if (isFirestorePermissionDenied(error)) return null;
      rethrow;
    }
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
    final companyRef = _companies.doc();
    await companyRef.set({
      'name': name,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'rubro': CompanyRubro.ambos.name,
    });
    await _writeOwnerProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      companyId: companyRef.id,
    );
  }

  @override
  Future<void> ensureOwnerProfile({
    required String uid,
    required String email,
    required String displayName,
    required Company company,
  }) {
    return _writeOwnerProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      companyId: company.id,
    );
  }

  Future<void> _writeOwnerProfile({
    required String uid,
    required String email,
    required String displayName,
    required String companyId,
  }) async {
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    batch.set(_members(companyId).doc(uid), {
      'role': CompanyRole.owner.name,
      'email': normalizeEmail(email),
      'displayName': displayName.trim(),
      'joinedAt': now,
    });
    batch.set(_users.doc(uid), {
      'email': normalizeEmail(email),
      'displayName': displayName.trim(),
      'companyId': companyId,
      'createdAt': now,
    });
    await batch.commit();
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
    final members = getFirestoreDocs(
      collection: _members(companyId),
      filters: [FirestoreFilter.equal('email', normalized)],
      limit: 1,
    );
    final pending = getFirestoreDocs(
      collection: _invitations(companyId),
      filters: [
        FirestoreFilter.equal('email', normalized),
        FirestoreFilter.equal('status', InvitationStatus.pending.name),
      ],
      limit: 1,
    );
    final memberDocs = await members;
    final pendingDocs = await pending;
    if (memberDocs.isNotEmpty) {
      throw const SessionException('Esa persona ya es miembro.');
    }
    if (pendingDocs.isNotEmpty) {
      throw const SessionException(
        'Ya hay una invitación pendiente para ese email.',
      );
    }

    final code = await _uniqueInviteCode(companyId);

    final ref = _invitations(companyId).doc();
    await ref.set({
      'email': normalized,
      'role': role.name,
      'status': InvitationStatus.pending.name,
      'invitedBy': invitedBy,
      'companyName': companyName.trim(),
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) {
      throw const SessionException('No se pudo crear la invitación.');
    }
    return Invitation.fromMap(snap.id, companyId, {
      ...data,
      'createdAt': data['createdAt'] ?? DateTime.now().toUtc(),
    });
  }

  @override
  Future<void> acceptInvitation({
    required String uid,
    required String email,
    required String displayName,
    required String companyId,
    required String invitationId,
  }) async {
    final invitationRef = _invitations(companyId).doc(invitationId);
    final memberRef = _members(companyId).doc(uid);
    final userRef = _users.doc(uid);
    final normalized = normalizeEmail(email);

    await _db.runTransaction((tx) async {
      final invitationSnap = await tx.get(invitationRef);
      if (!invitationSnap.exists || invitationSnap.data() == null) {
        throw const SessionException('La invitación no existe.');
      }
      final invitation = Invitation.fromMap(
        invitationSnap.id,
        companyId,
        invitationSnap.data()!,
      );
      if (!invitation.isPending) {
        throw const SessionException('Esta invitación ya no está disponible.');
      }
      if (invitation.email != normalized) {
        throw const SessionException('Esta invitación es para otro email.');
      }

      final userSnap = await tx.get(userRef);
      final existingCompanyId = userSnap.data()?['companyId'] as String?;
      if (existingCompanyId != null && existingCompanyId.isNotEmpty) {
        throw const SessionException('Ya pertenecés a una empresa.');
      }

      tx.update(invitationRef, {'status': InvitationStatus.accepted.name});
      tx.set(memberRef, {
        'role': invitation.role.name,
        'email': normalized,
        'displayName': displayName.trim(),
        'joinedAt': FieldValue.serverTimestamp(),
        'invitationId': invitationId,
      });
      tx.set(userRef, {
        'email': normalized,
        'displayName': displayName.trim(),
        'companyId': companyId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> revokeInvitation({
    required String companyId,
    required String invitationId,
  }) async {
    final ref = _invitations(companyId).doc(invitationId);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) {
      throw const SessionException('La invitación no existe.');
    }
    final invitation = Invitation.fromMap(snap.id, companyId, snap.data()!);
    if (!invitation.isPending) {
      throw const SessionException('Esta invitación ya no está pendiente.');
    }
    await ref.update({'status': InvitationStatus.revoked.name});
  }

  @override
  Future<void> removeMember({
    required String companyId,
    required String uid,
  }) async {
    final member = await getMembership(companyId, uid);
    if (member == null) {
      throw const SessionException('Esa persona no es miembro.');
    }
    if (member.role == CompanyRole.owner) {
      throw const SessionException('No se puede sacar al propietario.');
    }
    await _users.doc(uid).update({'companyId': ''});
    await _members(companyId).doc(uid).delete();
  }

  @override
  Future<void> clearOrphanCompany(String uid) async {
    final user = await getUser(uid);
    if (user == null || user.companyId.isEmpty) return;
    final member = await getMembership(user.companyId, uid);
    if (member != null) return;
    await _users.doc(uid).update({'companyId': ''});
  }

  @override
  Future<void> updateCompanyRubro(String companyId, CompanyRubro rubro) {
    return _updateCompany(companyId, {'rubro': rubro.name});
  }

  @override
  Future<void> updateCompanyPhone(String companyId, String? phone) {
    return _updateCompany(companyId, {'phone': blankToNull(phone)});
  }

  @override
  Future<void> updateCompanyName(String companyId, String name) {
    return _updateCompany(companyId, {'name': name.trim()});
  }

  @override
  Future<void> updateCompanyLogo(String companyId, String? logoUrl) {
    return _updateCompany(companyId, {'logoUrl': blankToNull(logoUrl)});
  }

  @override
  Future<void> updateCompanySocials(
    String companyId, {
    String? instagram,
    String? tiktok,
    String? facebook,
  }) {
    return _updateCompany(companyId, {
      'instagram': blankToNull(instagram),
      'tiktok': blankToNull(tiktok),
      'facebook': blankToNull(facebook),
    });
  }

  Future<void> _updateCompany(
    String companyId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _companies.doc(companyId).update(data);
    } on FirebaseException catch (error) {
      debugPrint('Company update failed code=${error.code} ${error.message}');
      throw SessionException(_companyUpdateMessage(error));
    }
  }

  String _companyUpdateMessage(FirebaseException error) {
    final code = error.code.replaceFirst('firestore/', '');
    switch (code) {
      case 'permission-denied':
        return 'No tenés permiso para cambiar el perfil del negocio.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'No se pudo guardar. Revisá la conexión e intentá de nuevo.';
      default:
        return 'No se pudo guardar el perfil del negocio.';
    }
  }

  Future<String> _uniqueInviteCode(String companyId) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = generateInviteCode();
      final docs = await getFirestoreDocs(
        collection: _invitations(companyId),
        filters: [FirestoreFilter.equal('code', code)],
        limit: 1,
      );
      if (docs.isEmpty) return code;
    }
    throw const SessionException('No se pudo crear la invitación.');
  }
}
