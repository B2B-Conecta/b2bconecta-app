/// Pestañas del hub de ajustes admin (Cuenta y preferencias).
enum AdminSettingsTab {
  perfil,
  notificaciones,
  seguridad,
  comisiones,
}

extension AdminSettingsTabX on AdminSettingsTab {
  String get label => switch (this) {
        AdminSettingsTab.perfil => 'Perfil',
        AdminSettingsTab.notificaciones => 'Notificaciones',
        AdminSettingsTab.seguridad => 'Seguridad',
        AdminSettingsTab.comisiones => 'Comisiones',
      };

  int get index => AdminSettingsTab.values.indexOf(this);

  static AdminSettingsTab fromIndex(int i) {
    final values = AdminSettingsTab.values;
    if (i < 0 || i >= values.length) return AdminSettingsTab.perfil;
    return values[i];
  }
}
