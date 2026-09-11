import 'dart:math';

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

const inviteCodeLength = 6;
const inviteCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String generateInviteCode([Random? random]) {
  final rng = random ?? Random.secure();
  return String.fromCharCodes(
    List.generate(inviteCodeLength, (_) {
      return inviteCodeAlphabet.codeUnitAt(
        rng.nextInt(inviteCodeAlphabet.length),
      );
    }),
  );
}

String normalizeInviteCode(String value) {
  return value.trim().toUpperCase().replaceAll(' ', '');
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
    this.code,
  });

  final String id;
  final String companyId;
  final String email;
  final CompanyRole role;
  final InvitationStatus status;
  final String invitedBy;
  final DateTime createdAt;
  final String? companyName;
  final String? code;

  bool get isPending => status == InvitationStatus.pending;

  String get path => '/invitar/$companyId/$id';

  factory Invitation.fromMap(
    String id,
    String companyId,
    Map<String, dynamic> map,
  ) {
    final rawCode = (map['code'] as String?)?.trim() ?? '';
    return Invitation(
      id: id,
      companyId: companyId,
      email: normalizeEmail(map['email'] as String? ?? ''),
      role: CompanyRole.fromStorage(map['role'] as String? ?? 'employee'),
      status: InvitationStatus.fromStorage(map['status'] as String? ?? ''),
      invitedBy: map['invitedBy'] as String? ?? '',
      createdAt: parseMapDate(map['createdAt']),
      companyName: (map['companyName'] as String?)?.trim(),
      code: rawCode.isEmpty ? null : normalizeInviteCode(rawCode),
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
      if (code != null && code!.isNotEmpty) 'code': code,
    };
  }

  Invitation copyWith({InvitationStatus? status, String? code}) {
    return Invitation(
      id: id,
      companyId: companyId,
      email: email,
      role: role,
      status: status ?? this.status,
      invitedBy: invitedBy,
      createdAt: createdAt,
      companyName: companyName,
      code: code ?? this.code,
    );
  }
}
