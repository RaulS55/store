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
    required this.cuit,
    required this.taxCondition,
    this.address,
  });

  final String id;
  final String name;
  final String cuit;
  final TaxCondition taxCondition;
  final String? address;
}
