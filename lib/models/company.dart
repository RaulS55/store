import 'map_date.dart';

enum CompanyRubro {
  ropa('Ropa'),
  calzado('Calzado'),
  ambos('Ropa y calzado');

  const CompanyRubro(this.label);
  final String label;

  bool get includesRopa => this != CompanyRubro.calzado;

  bool get includesCalzado => this != CompanyRubro.ropa;

  static CompanyRubro fromStorage(String? value) {
    for (final rubro in CompanyRubro.values) {
      if (rubro.name == value) return rubro;
    }
    return CompanyRubro.ambos;
  }

  static CompanyRubro fromSelection({
    required bool ropa,
    required bool calzado,
  }) {
    if (ropa && calzado) return CompanyRubro.ambos;
    if (calzado) return CompanyRubro.calzado;
    return CompanyRubro.ropa;
  }
}

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    this.rubro = CompanyRubro.ambos,
  });

  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final CompanyRubro rubro;

  factory Company.fromMap(String id, Map<String, dynamic> map) {
    return Company(
      id: id,
      name: (map['name'] as String? ?? '').trim(),
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: parseMapDate(map['createdAt']),
      rubro: CompanyRubro.fromStorage(map['rubro'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
      'rubro': rubro.name,
    };
  }

  Company copyWith({
    String? id,
    String? name,
    String? ownerId,
    DateTime? createdAt,
    CompanyRubro? rubro,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      rubro: rubro ?? this.rubro,
    );
  }
}
