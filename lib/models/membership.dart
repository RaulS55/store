import 'company_role.dart';
import 'email.dart';
import 'map_date.dart';

class Membership {
  const Membership({
    required this.uid,
    required this.companyId,
    required this.role,
    required this.email,
    required this.displayName,
    required this.joinedAt,
    this.invitationId,
  });

  final String uid;
  final String companyId;
  final CompanyRole role;
  final String email;
  final String displayName;
  final DateTime joinedAt;
  final String? invitationId;

  factory Membership.fromMap(
    String uid,
    String companyId,
    Map<String, dynamic> map,
  ) {
    return Membership(
      uid: uid,
      companyId: companyId,
      role: CompanyRole.fromStorage(map['role'] as String? ?? ''),
      email: normalizeEmail(map['email'] as String? ?? ''),
      displayName: (map['displayName'] as String? ?? '').trim(),
      joinedAt: parseMapDate(map['joinedAt']),
      invitationId: map['invitationId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.name,
      'email': normalizeEmail(email),
      'displayName': displayName.trim(),
      'joinedAt': joinedAt.toIso8601String(),
      if (invitationId != null) 'invitationId': invitationId,
    };
  }
}
