import 'package:shared_preferences/shared_preferences.dart';

/// Rol B2B elegido en `/registro` antes de completar el perfil.
abstract final class PendingSignupRoleStorage {
  static const _key = 'b2b_pending_signup_role';

  static Future<void> save(String? role) async {
    final r = role?.trim().toLowerCase() ?? '';
    final prefs = await SharedPreferences.getInstance();
    if (r != 'aliado' && r != 'importador') {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, r);
  }

  static Future<String?> peek() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.getString(_key)?.trim().toLowerCase() ?? '';
    if (r != 'aliado' && r != 'importador') return null;
    return r;
  }

  static Future<String?> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.getString(_key)?.trim().toLowerCase() ?? '';
    await prefs.remove(_key);
    if (r != 'aliado' && r != 'importador') return null;
    return r;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
