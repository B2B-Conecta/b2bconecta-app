/// Etiqueta corta en español para el rol B2B (`profiles.role`).
/// En UI, el rol interno `aliado` se muestra como Minorista.
abstract final class ProfileRoleLabels {
  static const aliadoEs = 'Minorista';
  static const aliadosEs = 'Minoristas';

  static String labelEs(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'importador':
        return 'Importador';
      case 'aliado':
        return aliadoEs;
      case 'administrador':
        return 'Administración';
      default:
        return 'Usuario';
    }
  }
}
