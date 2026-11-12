/// Validación del alta / expediente que carga el owner (la autoridad real está en SQL).
abstract final class OwnerAccountCreateRules {
  static const minPasswordLength = 6;

  static bool isValidEmail(String raw) {
    final e = raw.trim();
    if (e.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  /// RIF venezolano flexible (J-12345678-9 / V12345678 / vacío permitido).
  static final _rifPattern = RegExp(
    r'^[JGVEPCjgvepc][-.]?\d{6,9}[-.]?\d?$',
  );

  static String? emailError(String raw, {bool required = true}) {
    final e = raw.trim();
    if (e.isEmpty) return required ? 'Indique un correo válido.' : null;
    if (!isValidEmail(e)) return 'Correo inválido.';
    return null;
  }

  static String? passwordError(String raw) {
    if (raw.length < minPasswordLength) {
      return 'Mínimo $minPasswordLength caracteres.';
    }
    return null;
  }

  static String? passwordConfirmError(String password, String confirm) {
    if (confirm.isEmpty) return 'Confirme la contraseña.';
    if (password != confirm) return 'Las contraseñas no coinciden.';
    return null;
  }

  static String? businessNameError(String raw) {
    if (raw.trim().isEmpty) return 'Indique el nombre comercial.';
    return null;
  }

  static String? rifError(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final compact = t.replaceAll(' ', '');
    if (!_rifPattern.hasMatch(compact)) {
      return 'Formato RIF sugerido: J-12345678-9';
    }
    return null;
  }

  static String? phoneError(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'Teléfono demasiado corto.';
    return null;
  }

  static String? validateCreate({
    required String email,
    required String password,
    required String passwordConfirm,
    required String businessName,
    required String role,
    bool allowAdminRole = true,
    String rif = '',
    String phone = '',
  }) {
    return emailError(email) ??
        passwordError(password) ??
        passwordConfirmError(password, passwordConfirm) ??
        businessNameError(businessName) ??
        rifError(rif) ??
        phoneError(phone) ??
        () {
          final r = role.trim().toLowerCase();
          if (r == 'administrador' && !allowAdminRole) {
            return 'Solo el propietario puede crear cuentas de administración.';
          }
          if (r != 'aliado' && r != 'importador' && r != 'administrador') {
            return 'Elija un rol.';
          }
          return null;
        }();
  }

  static String? validateDossier({
    required String businessName,
    String rif = '',
    String phone = '',
    String legalEmail = '',
  }) {
    return businessNameError(businessName) ??
        rifError(rif) ??
        phoneError(phone) ??
        emailError(legalEmail, required: false);
  }
}
