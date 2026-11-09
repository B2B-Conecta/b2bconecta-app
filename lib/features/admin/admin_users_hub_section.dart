/// Secciones del hub unificado de usuarios (admin).
enum AdminUsersHubSection {
  verificacion,
  cuentas,
  actividad,
}

extension AdminUsersHubSectionLabel on AdminUsersHubSection {
  String get labelEs => switch (this) {
        AdminUsersHubSection.verificacion => 'Verificación',
        AdminUsersHubSection.cuentas => 'Cuentas',
        AdminUsersHubSection.actividad => 'Actividad',
      };
}
