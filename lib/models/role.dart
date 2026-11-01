enum Role {
  admin('admin', 'Администратор'),
  doctor('doctor', 'Врач'),
  registrar('registrar', 'Регистратор');

  final String value;
  final String label;

  const Role(this.value, this.label);

  static Role fromString(String? value) {
    for (final role in Role.values) {
      if (role.value == value) return role;
    }
    return Role.registrar;
  }
}
