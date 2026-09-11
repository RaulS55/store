import 'map_date.dart';

class SyncRecord {
  const SyncRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory SyncRecord.create(String id, {DateTime? now}) {
    final stamp = (now ?? DateTime.now()).toUtc();
    return SyncRecord(id: id, createdAt: stamp, updatedAt: stamp);
  }

  factory SyncRecord.fromMap(String id, Map<String, dynamic> map) {
    final raw = (map['id'] as String?)?.trim() ?? '';
    return SyncRecord(
      id: raw.isEmpty ? id : raw,
      createdAt: parseMapDate(map['createdAt']),
      updatedAt: parseMapDate(map['updatedAt']),
      deletedAt: parseOptionalMapDate(map['deletedAt']),
    );
  }

  SyncRecord touch({DateTime? now}) {
    return SyncRecord(
      id: id,
      createdAt: createdAt,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      deletedAt: deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
    };
  }
}
