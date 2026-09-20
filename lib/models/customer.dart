import 'map_value.dart';
import 'sync_record.dart';

enum TaxCondition {
  responsableInscripto('Responsable Inscripto'),
  monotributo('Monotributo'),
  consumidorFinal('Consumidor Final'),
  exento('Exento');

  const TaxCondition(this.label);
  final String label;

  static TaxCondition? fromStorage(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    for (final condition in TaxCondition.values) {
      if (condition.name == raw) return condition;
    }
    throw FormatException('Unknown tax condition: $value');
  }
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.cuit,
    this.taxCondition,
    this.phone,
    this.address,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String? cuit;
  final TaxCondition? taxCondition;
  final String? phone;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  String get whatsappDigits => (phone ?? '').replaceAll(RegExp(r'\D'), '');

  Customer copyWith({
    String? id,
    String? name,
    String? cuit,
    TaxCondition? taxCondition,
    String? phone,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      cuit: cuit ?? this.cuit,
      taxCondition: taxCondition ?? this.taxCondition,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  String? get detailSubtitle {
    final parts = <String>[];
    final phoneText = phone?.trim();
    final cuitText = cuit?.trim();
    if (phoneText != null && phoneText.isNotEmpty) parts.add(phoneText);
    if (cuitText != null && cuitText.isNotEmpty) parts.add('CUIT $cuitText');
    if (taxCondition != null) parts.add(taxCondition!.label);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    final record = SyncRecord.fromMap(id, data);
    return Customer(
      id: record.id,
      name: (data['name'] as String? ?? '').trim(),
      cuit: _blankToNull(data['cuit'] as String?),
      taxCondition: TaxCondition.fromStorage(data['taxCondition'] as String?),
      phone: _blankToNull(data['phone'] as String?),
      address: _blankToNull(data['address'] as String?),
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
      'cuit': cuit?.trim(),
      'taxCondition': taxCondition?.name,
      'phone': phone?.trim(),
      'address': address?.trim(),
    };
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
