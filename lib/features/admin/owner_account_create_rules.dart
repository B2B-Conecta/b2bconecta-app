/// Validación del alta / expediente que carga el owner (la autoridad real está en SQL).
abstract final class OwnerAccountCreateRules {
  static const minPasswordLength = 6;

  static bool isValidEmail(String raw) {
    final e = raw.trim();
    if (e.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  static String? validateCreate({
    required String email,
    required String password,
    required String passwordConfirm,
    required String businessName,
    required String role,
  }) {
    if (!isValidEmail(email)) return 'Indique un correo válido.';
    if (password.length < minPasswordLength) {
      return 'La contraseña debe tener al menos $minPasswordLength caracteres.';
    }
    if (password != passwordConfirm) return 'Las contraseñas no coinciden.';
    if (businessName.trim().isEmpty) return 'Indique el nombre comercial.';
    final r = role.trim().toLowerCase();
    if (r != 'aliado' && r != 'importador' && r != 'administrador') {
      return 'Elija un rol.';
    }
    return null;
  }

  static String? validateDossier({required String businessName}) {
    if (businessName.trim().isEmpty) return 'Indique el nombre comercial.';
    return null;
  }
}
