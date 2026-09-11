import 'company_role.dart';
import 'email.dart';
import 'map_date.dart';

enum InvitationStatus {
  pending,
  accepted,
  revoked;

  static InvitationStatus fromStorage(String value) {
    for (final status in InvitationStatus.values) {
      if (status.name == value) return status;
    }
    throw FormatException('Unknown invitation status: $value');
  }
}

class Invitation {
  const Invitation({
    required this.id,
    required this.companyId,
    required this.email,
    required this.role,
    required this.status,
    required this.invitedBy,
    required this.createdAt,
    this.companyName,
  });

  final String id;
  final String companyId;
  final String email;
  final CompanyRole role;
  final InvitationStatus status;
  final String invitedBy;
  final DateTime createdAt;
  final String? companyName;

  bool get isPending => status == InvitationStatus.pending;

  String get path => '/invitar/$companyId/$id';

  factory Invitation.fromMap(
    String id,
    String companyId,
    Map<String, dynamic> map,
  ) {
    return Invitation(
      id: id,
      companyId: companyId,
      email: normalizeEmail(map['email'] as String? ?? ''),
      role: CompanyRole.fromStorage(map['role'] as String? ?? 'employee'),
      status: InvitationStatus.fromStorage(map['status'] as String? ?? ''),
      invitedBy: map['invitedBy'] as String? ?? '',
      createdAt: parseMapDate(map['createdAt']),
      companyName: (map['companyName'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': normalizeEmail(email),
      'role': role.name,
      'status': status.name,
      'invitedBy': invitedBy,
      'createdAt': createdAt.toIso8601String(),
      if (companyName != null && companyName!.isNotEmpty)
        'companyName': companyName,
    };
  }

  Invitation copyWith({InvitationStatus? status}) {
    return Invitation(
      id: id,
      companyId: companyId,
      email: email,
      role: role,
      status: status ?? this.status,
      invitedBy: invitedBy,
      createdAt: createdAt,
      companyName: companyName,
    );
  }
}
