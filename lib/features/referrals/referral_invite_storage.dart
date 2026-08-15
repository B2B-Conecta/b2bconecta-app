import 'package:shared_preferences/shared_preferences.dart';

/// Código de referido capturado desde `?ref=` o el formulario de registro
/// hasta que se asocie al perfil.
abstract final class ReferralInviteStorage {
  static const _key = 'b2b_pending_referral_code';

  static String normalize(String? raw) {
    final t = raw?.trim().toUpperCase() ?? '';
    if (t.isEmpty) return '';
    return t.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static Future<void> savePendingCode(String? raw) async {
    final code = normalize(raw);
    final prefs = await SharedPreferences.getInstance();
    if (code.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, code);
  }

  static Future<String?> peekPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = normalize(prefs.getString(_key));
    return code.isEmpty ? null : code;
  }

  static Future<String?> consumePendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = normalize(prefs.getString(_key));
    if (code.isEmpty) return null;
    await prefs.remove(_key);
    return code;
  }

  static Future<void> clearPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
