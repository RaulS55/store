import 'email.dart';
import 'map_date.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.companyId,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String companyId;
  final DateTime createdAt;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: normalizeEmail(map['email'] as String? ?? ''),
      displayName: (map['displayName'] as String? ?? '').trim(),
      companyId: map['companyId'] as String? ?? '',
      createdAt: parseMapDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': normalizeEmail(email),
      'displayName': displayName.trim(),
      'companyId': companyId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
