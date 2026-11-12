/// Secciones del hub unificado de usuarios (admin).
enum AdminUsersHubSection {
  cuentas,
  actividad,
  sellosYVitrina,
}

extension AdminUsersHubSectionLabel on AdminUsersHubSection {
  String get labelEs => switch (this) {
        AdminUsersHubSection.cuentas => 'Cuentas',
        AdminUsersHubSection.actividad => 'Actividad',
        AdminUsersHubSection.sellosYVitrina => 'Sellos y Vitrina',
      };

  String get hintEs => switch (this) {
        AdminUsersHubSection.cuentas =>
          'Tabla fiscal, roles, KYC, alta, baja suave y purga total.',
        AdminUsersHubSection.actividad =>
          'Auditoría en tiempo real: fecha, IP/origen, acción y responsable.',
        AdminUsersHubSection.sellosYVitrina =>
          'Verificado y Destacado de mayoristas e importadores en el marketplace.',
      };

  /// Segmentos del hub en móvil.
  static const mobileSegments = <AdminUsersHubSection>[
    AdminUsersHubSection.cuentas,
    AdminUsersHubSection.actividad,
    AdminUsersHubSection.sellosYVitrina,
  ];
}
