/// Etiqueta corta en español para el rol B2B (`profiles.role`).
abstract final class ProfileRoleLabels {
  static String labelEs(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'importador':
        return 'Importador';
      case 'aliado':
        return 'Aliado';
      case 'administrador':
        return 'Administración';
      default:
        return 'Usuario';
    }
  }
}
