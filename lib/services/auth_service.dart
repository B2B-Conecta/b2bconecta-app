import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_recovery_storage.dart';
import '../config/auth_redirect_config.dart';
import 'push_notification_service.dart';

/// Operaciones de Supabase Auth (login, registro, recuperación, actualización).
class AuthService {
  AuthService._();

  static GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Redirect post-auth (recovery / confirmación).
  ///
  /// En **web** usa el origen actual ([Uri.base.origin]) para que el correo
  /// vuelva a la misma app donde se pidió el enlace (localhost, Vercel o prod).
  /// Ese origen debe estar en Supabase Auth → Redirect URLs
  /// (`config/supabase-auth-redirects.example`).
  ///
  /// En **móvil** usa `.env` → `SUPABASE_AUTH_REDIRECT_URL` (deep link).
  static String? get authRedirectUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin.trim();
      if (origin.isNotEmpty && origin != 'null') return origin;
    }
    final redirect = dotenv.env['SUPABASE_AUTH_REDIRECT_URL']?.trim();
    return redirect != null && redirect.isNotEmpty ? redirect : null;
  }

  /// Orígenes web conocidos (dev / prod / local) — referencia; allow-list en Dashboard.
  static List<String> get knownWebRedirectOrigins => [
        AuthRedirectConfig.stagingWebRedirectUrl,
        AuthRedirectConfig.productionWebRedirectUrl,
        AuthRedirectConfig.localWebRedirectUrl,
        'http://127.0.0.1:3000',
      ];

  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    String? referralCode,
  }) {
    final code = referralCode?.trim().toUpperCase();
    return _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: authRedirectUrl,
      data: (code != null && code.isNotEmpty)
          ? <String, dynamic>{'referral_code': code}
          : null,
    );
  }

  /// Recovery: [redirectTo] = origen web actual o deep link móvil.
  static Future<void> resetPasswordForEmail(String email) async {
    await AuthRecoveryStorage.markPendingPasswordRecovery();
    await _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: authRedirectUrl,
    );
  }

  /// Cambia la contraseña del usuario con sesión activa.
  static Future<UserResponse> updatePassword(String newPassword) {
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  static Future<void> signOut() async {
    await AuthRecoveryStorage.clearPendingPasswordRecovery();
    await PushNotificationService.instance.unregisterCurrentDevice();
    await _auth.signOut();
  }

  /// Mensajes legibles para [AuthException.message] y respuestas genéricas.
  static String mapAuthErrorMessage(String? raw) {
    final m = raw?.toLowerCase() ?? '';
    if (m.contains('invalid') && m.contains('credential')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('email') && m.contains('confirm')) {
      return 'Debes confirmar tu correo antes de iniciar sesión.';
    }
    if (m.contains('already') && m.contains('registered')) {
      return 'Ese correo ya está registrado. Inicia sesión o recupera la contraseña.';
    }
    if (m.contains('user') && m.contains('already')) {
      return 'Ese correo ya está registrado.';
    }
    if (m.contains('too many')) {
      return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
    }
    if (m.contains('password') && m.contains('least')) {
      return 'La contraseña no cumple los requisitos mínimos.';
    }
    if (m.contains('signup') && m.contains('disabled')) {
      return 'El registro está deshabilitado en este momento.';
    }
    if (m.contains('code verifier')) {
      return 'Abre el enlace en el mismo navegador donde solicitaste '
          'la recuperación de contraseña.';
    }
    return raw?.isNotEmpty == true
        ? raw!
        : 'No se pudo completar la operación.';
  }
}
