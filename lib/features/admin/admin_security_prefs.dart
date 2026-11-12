import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales de seguridad admin (2FA UI + sesiones simuladas).
class AdminSecurityPrefs {
  AdminSecurityPrefs._();

  static const _enabledKey = 'admin_security_2fa_enabled';
  static const _secretKey = 'admin_security_2fa_secret';
  static const _sessionsKey = 'admin_security_sessions_revoked';

  bool twoFactorEnabled = false;
  String totpSecret = '';

  /// IDs de sesiones revocadas (además de las quitadas de la lista en memoria).
  Set<String> revokedSessionIds = {};

  static String generateTotpSecret() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final rng = Random.secure();
    return List.generate(16, (_) => alphabet[rng.nextInt(alphabet.length)])
        .join();
  }

  static Future<AdminSecurityPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final secret = prefs.getString(_secretKey)?.trim() ?? '';
    final revokedRaw = prefs.getString(_sessionsKey);
    final revoked = <String>{};
    if (revokedRaw != null && revokedRaw.isNotEmpty) {
      try {
        final list = jsonDecode(revokedRaw) as List<dynamic>;
        revoked.addAll(list.map((e) => e.toString()));
      } catch (_) {}
    }
    return AdminSecurityPrefs._()
      ..twoFactorEnabled = prefs.getBool(_enabledKey) ?? false
      ..totpSecret = secret.isEmpty ? generateTotpSecret() : secret
      ..revokedSessionIds = revoked;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, twoFactorEnabled);
    await prefs.setString(_secretKey, totpSecret);
    await prefs.setString(
      _sessionsKey,
      jsonEncode(revokedSessionIds.toList()),
    );
  }
}

/// Sesión de dispositivo mostrada en Ajustes → Seguridad.
class AdminDeviceSession {
  const AdminDeviceSession({
    required this.id,
    required this.deviceLabel,
    required this.locationLabel,
    required this.lastActiveLabel,
    required this.isMobile,
    this.isCurrent = false,
  });

  final String id;
  final String deviceLabel;
  final String locationLabel;
  final String lastActiveLabel;
  final bool isMobile;
  final bool isCurrent;
}
