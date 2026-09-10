enum TaxCondition {
  responsableInscripto('Responsable Inscripto'),
  monotributo('Monotributo'),
  consumidorFinal('Consumidor Final'),
  exento('Exento');

  const TaxCondition(this.label);
  final String label;
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.cuit,
    this.taxCondition,
    this.phone,
    this.address,
  });

  final String id;
  final String name;
  final String? cuit;
  final TaxCondition? taxCondition;
  final String? phone;
  final String? address;

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
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      cuit: cuit ?? this.cuit,
      taxCondition: taxCondition ?? this.taxCondition,
      phone: phone ?? this.phone,
      address: address ?? this.address,
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
}
