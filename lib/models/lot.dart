import 'map_date.dart';
import 'map_value.dart';
import 'sync_record.dart';

String formatLotDay(DateTime value) {
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  return '$dd/$mm/${value.year}';
}

class Lot {
  const Lot({
    required this.id,
    this.name = '',
    required this.cost,
    this.quantity,
    this.unitCost,
    this.soldElsewhere = 0,
    this.date,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final double cost;
  final int? quantity;
  final double? unitCost;
  final double soldElsewhere;
  final DateTime? date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'Lote · $dateLabel';
  }

  DateTime get calendarDate {
    final source = date ?? createdAt.toUtc();
    return DateTime(source.year, source.month, source.day);
  }

  String get dateLabel => formatLotDay(calendarDate);

  double? get derivedUnitCost {
    if (unitCost != null) return unitCost;
    final qty = quantity;
    if (qty == null || qty <= 0) return null;
    return cost / qty;
  }

  factory Lot.fromMap(String id, Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    final record = SyncRecord.fromMap(id, data);
    final rawQuantity = data['quantity'] as num?;
    final quantity = rawQuantity?.toInt();
    return Lot(
      id: record.id,
      name: (data['name'] as String? ?? '').trim(),
      cost: (data['cost'] as num?)?.toDouble() ?? 0,
      quantity: quantity == null || quantity <= 0 ? null : quantity,
      unitCost: (data['unitCost'] as num?)?.toDouble(),
      soldElsewhere: (data['soldElsewhere'] as num?)?.toDouble() ?? 0,
      date: parseOptionalMapDate(data['date']),
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
      'name': name.trim(),
      'cost': cost,
      'quantity': quantity,
      'unitCost': unitCost,
      'soldElsewhere': soldElsewhere,
      'date': date?.toUtc().toIso8601String(),
    };
  }

  Lot copyWith({
    String? id,
    String? name,
    double? cost,
    int? quantity,
    double? unitCost,
    double? soldElsewhere,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Lot(
      id: id ?? this.id,
      name: name ?? this.name,
      cost: cost ?? this.cost,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      soldElsewhere: soldElsewhere ?? this.soldElsewhere,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
