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

  bool get canViewTeam => switch (this) {
    CompanyRole.owner => true,
    CompanyRole.administrator => true,
    CompanyRole.employee => false,
  };

  bool get canDeleteProduct => switch (this) {
    CompanyRole.owner => true,
    CompanyRole.administrator => true,
    CompanyRole.employee => false,
  };

  bool get canDeleteCustomer => switch (this) {
    CompanyRole.owner => true,
    CompanyRole.administrator => true,
    CompanyRole.employee => false,
  };

  bool get canEditCompanySettings => switch (this) {
    CompanyRole.owner => true,
    CompanyRole.administrator => true,
    CompanyRole.employee => false,
  };

  bool get canManageLots => switch (this) {
    CompanyRole.owner => true,
    CompanyRole.administrator => true,
    CompanyRole.employee => false,
  };

  bool get canViewLotStats => switch (this) {
    CompanyRole.owner => true,
    CompanyRole.administrator => false,
    CompanyRole.employee => false,
  };

  static const assignable = [CompanyRole.administrator, CompanyRole.employee];

  static CompanyRole fromStorage(String value) {
    for (final role in CompanyRole.values) {
      if (role.name == value) return role;
    }
    throw FormatException('Unknown company role: $value');
  }
}
