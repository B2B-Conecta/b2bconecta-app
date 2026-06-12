import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_notification_service.dart';

/// Operaciones de Supabase Auth (login, registro, recuperación, actualización).
class AuthService {
  AuthService._();

  static GoTrueClient get _auth => Supabase.instance.client.auth;

  /// URL post-auth (recovery, confirmación de registro). Ver `.env` → `SUPABASE_AUTH_REDIRECT_URL`.
  static String? get authRedirectUrl {
    final redirect = dotenv.env['SUPABASE_AUTH_REDIRECT_URL']?.trim();
    return redirect != null && redirect.isNotEmpty ? redirect : null;
  }

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
  }) {
    return _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: authRedirectUrl,
    );
  }

  /// [redirectTo] opcional vía `.env` → `SUPABASE_AUTH_REDIRECT_URL` (URL de tu app web o deep link).
  static Future<void> resetPasswordForEmail(String email) {
    return _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: authRedirectUrl,
    );
  }

  /// Cambia la contraseña del usuario con sesión activa.
  static Future<UserResponse> updatePassword(String newPassword) {
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  static Future<void> signOut() async {
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
    return raw?.isNotEmpty == true
        ? raw!
        : 'No se pudo completar la operación.';
  }
}
