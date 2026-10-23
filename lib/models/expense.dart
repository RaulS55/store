import 'map_value.dart';
import 'sync_record.dart';

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final double amount;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  String get displayName {
    final trimmed = note.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'Otro gasto';
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    final record = SyncRecord.fromMap(id, data);
    return Expense(
      id: record.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      note: (data['note'] as String? ?? '').trim(),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...SyncRecord(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      ).toMap(),
      'amount': amount,
      'note': note.trim(),
    };
  }

  Expense copyWith({
    String? id,
    double? amount,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
