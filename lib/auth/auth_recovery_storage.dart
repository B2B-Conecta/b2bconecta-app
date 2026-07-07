import 'package:shared_preferences/shared_preferences.dart';

/// Marca localmente que el usuario inició recuperación de contraseña (PKCE web).
abstract final class AuthRecoveryStorage {
  static const _key = 'motolink_pending_password_recovery';

  static Future<void> markPendingPasswordRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  static Future<bool> peekPendingPasswordRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<bool> consumePendingPasswordRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_key) ?? false;
    if (pending) {
      await prefs.remove(_key);
    }
    return pending;
  }

  static Future<void> clearPendingPasswordRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
