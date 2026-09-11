enum CompanyRole {
  owner,
  administrator,
  employee;

  String get label => switch (this) {
    CompanyRole.owner => 'Propietario',
    CompanyRole.administrator => 'Administrador',
    CompanyRole.employee => 'Empleado',
  };

  bool get isAssignable =>
      this == CompanyRole.administrator || this == CompanyRole.employee;

  static const assignable = [CompanyRole.administrator, CompanyRole.employee];

  static CompanyRole fromStorage(String value) {
    for (final role in CompanyRole.values) {
      if (role.name == value) return role;
    }
    throw FormatException('Unknown company role: $value');
  }
}
