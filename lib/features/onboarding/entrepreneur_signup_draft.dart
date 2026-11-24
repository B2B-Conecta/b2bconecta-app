import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Datos del alta emprendedor guardados antes del redirect de Gmail.
abstract final class EntrepreneurSignupDraft {
  static const _key = 'b2b_entrepreneur_gmail_draft';

  static Future<void> save({
    required String phone,
    required String rif,
    required String cedula,
    required String direccion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'phone': phone.trim(),
        'rif': rif.trim(),
        'cedula': cedula.trim(),
        'direccion': direccion.trim(),
      }),
    );
  }

  static Future<Map<String, String>?> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    await prefs.remove(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      String text(String key) => decoded[key]?.toString().trim() ?? '';
      final draft = {
        'phone': text('phone'),
        'rif': text('rif'),
        'cedula': text('cedula'),
        'direccion': text('direccion'),
      };
      if (draft.values.any((v) => v.isEmpty)) return null;
      return draft;
    } catch (_) {
      return null;
    }
  }
}
