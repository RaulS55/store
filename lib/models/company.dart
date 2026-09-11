import 'map_date.dart';

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  factory Company.fromMap(String id, Map<String, dynamic> map) {
    return Company(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: parseMapDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
