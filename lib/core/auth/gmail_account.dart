import 'package:shared_preferences/shared_preferences.dart';

/// Correo de Gmail. El registro de escritorio solo acepta estas cuentas.
bool isGmailAddress(String? email) {
  final value = email?.trim().toLowerCase() ?? '';
  return value.endsWith('@gmail.com') || value.endsWith('@googlemail.com');
}

/// Marca un alta por Gmail antes del redirect. El inicio de sesión no la usa.
abstract final class GmailSignupIntent {
  static const _key = 'b2b_gmail_signup_intent';

  static Future<void> mark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<bool> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_key) ?? false;
    if (pending) await prefs.remove(_key);
    return pending;
  }
}
