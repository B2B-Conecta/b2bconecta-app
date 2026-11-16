/// Utilidades para interpretar fragmentos `#...` / query de enlaces Auth (web / deep links).

enum AuthCallbackKind {
  /// Restablecer contraseña.
  recovery,

  /// Confirmación de correo tras registro.
  signup,

  /// Magic link / invite / desconocido con sesión.
  other,
}

class AuthLinkParseResult {
  const AuthLinkParseResult({
    required this.kind,
    this.errorMessage,
  });

  final AuthCallbackKind kind;
  final String? errorMessage;

  bool get isPasswordRecovery => kind == AuthCallbackKind.recovery;
  bool get isSignupConfirmation => kind == AuthCallbackKind.signup;
}

/// Indica si la URL actual trae un callback de Supabase Auth (PKCE, implicit o error).
bool hasAuthCallbackInUri(Uri uri) {
  if (uri.fragment.isNotEmpty) {
    final fragment = Uri.splitQueryString(uri.fragment);
    if (fragment.containsKey('access_token') ||
        fragment.containsKey('error') ||
        fragment.containsKey('error_description')) {
      return true;
    }
  }
  if (uri.queryParameters.containsKey('code')) return true;
  if (uri.queryParameters.containsKey('error') ||
      uri.queryParameters.containsKey('error_description')) {
    return true;
  }
  return false;
}

AuthLinkParseResult parseAuthUriFragment(Uri uri) {
  final params = _authParamsFromUri(uri);
  if (params.isEmpty) {
    return const AuthLinkParseResult(kind: AuthCallbackKind.other);
  }
  final error = params['error']?.trim();
  final errorCode = params['error_code']?.trim();
  final kind = _kindFromType(params['type']);
  if ((error != null && error.isNotEmpty) ||
      (errorCode != null && errorCode.isNotEmpty)) {
    return AuthLinkParseResult(
      kind: kind,
      errorMessage: mapAuthLinkError(params, kind: kind),
    );
  }

  return AuthLinkParseResult(kind: kind);
}

AuthCallbackKind _kindFromType(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'recovery':
      return AuthCallbackKind.recovery;
    case 'signup':
    case 'email':
    case 'email_change':
      return AuthCallbackKind.signup;
    default:
      return AuthCallbackKind.other;
  }
}

/// Recuperación PKCE: el flag local persiste aunque `detectSessionInUri` consuma el `code`.
bool shouldForcePasswordRecoveryScreen({
  required bool awaitingPasswordRecovery,
  required bool pendingPasswordRecovery,
}) =>
    awaitingPasswordRecovery || pendingPasswordRecovery;

Map<String, String> _authParamsFromUri(Uri uri) {
  if (uri.fragment.isNotEmpty) {
    return Uri.splitQueryString(uri.fragment);
  }
  final type = uri.queryParameters['type']?.trim();
  if (type != null && type.isNotEmpty) {
    return Map<String, String>.from(uri.queryParameters);
  }
  final error = uri.queryParameters['error']?.trim();
  final errorCode = uri.queryParameters['error_code']?.trim();
  if ((error != null && error.isNotEmpty) ||
      (errorCode != null && errorCode.isNotEmpty)) {
    return Map<String, String>.from(uri.queryParameters);
  }
  // PKCE solo con ?code= (sin type): no hay params tipados.
  if (uri.queryParameters.containsKey('code')) {
    return Map<String, String>.from(uri.queryParameters);
  }
  return const {};
}

String mapAuthLinkError(
  Map<String, String> params, {
  AuthCallbackKind kind = AuthCallbackKind.other,
}) {
  final code = (params['error_code'] ?? params['error'] ?? '').toLowerCase();
  final description = _decodeParam(params['error_description'] ?? '');

  if (code.contains('otp_expired') ||
      description.toLowerCase().contains('expired')) {
    return kind == AuthCallbackKind.signup
        ? 'El enlace de confirmación expiró o ya fue usado. Puedes reenviar el correo o iniciar sesión si ya confirmaste.'
        : 'El enlace del correo expiró o ya fue usado. Solicita uno nuevo.';
  }
  if (code.contains('access_denied') && description.isNotEmpty) {
    return description;
  }
  if (description.isNotEmpty) {
    return description;
  }
  return kind == AuthCallbackKind.signup
      ? 'No se pudo confirmar el correo desde este enlace.'
      : 'No se pudo completar la autenticación desde el enlace.';
}

String _decodeParam(String raw) {
  if (raw.isEmpty) return raw;
  return Uri.decodeComponent(raw.replaceAll('+', ' '));
}
