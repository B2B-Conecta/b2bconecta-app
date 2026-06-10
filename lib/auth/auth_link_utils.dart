/// Utilidades para interpretar fragmentos `#...` de enlaces Auth (web / deep links).
class AuthLinkParseResult {
  const AuthLinkParseResult({
    required this.isPasswordRecovery,
    this.errorMessage,
  });

  final bool isPasswordRecovery;
  final String? errorMessage;
}

AuthLinkParseResult parseAuthUriFragment(Uri uri) {
  final params = _authParamsFromUri(uri);
  if (params.isEmpty) {
    return const AuthLinkParseResult(isPasswordRecovery: false);
  }
  final error = params['error']?.trim();
  final errorCode = params['error_code']?.trim();
  if ((error != null && error.isNotEmpty) ||
      (errorCode != null && errorCode.isNotEmpty)) {
    return AuthLinkParseResult(
      isPasswordRecovery: false,
      errorMessage: mapAuthLinkError(params),
    );
  }

  if (params['type'] == 'recovery') {
    return const AuthLinkParseResult(isPasswordRecovery: true);
  }

  return const AuthLinkParseResult(isPasswordRecovery: false);
}

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
  return const {};
}

String mapAuthLinkError(Map<String, String> params) {
  final code = (params['error_code'] ?? params['error'] ?? '').toLowerCase();
  final description = _decodeParam(params['error_description'] ?? '');

  if (code.contains('otp_expired') || description.toLowerCase().contains('expired')) {
    return 'El enlace del correo expiró o ya fue usado. Solicita uno nuevo.';
  }
  if (code.contains('access_denied') && description.isNotEmpty) {
    return description;
  }
  if (description.isNotEmpty) {
    return description;
  }
  return 'No se pudo completar la autenticación desde el enlace.';
}

String _decodeParam(String raw) {
  if (raw.isEmpty) return raw;
  return Uri.decodeComponent(raw.replaceAll('+', ' '));
}
