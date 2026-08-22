import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ad_attribution.dart';

/// UTM / fbclid del landing hasta que se escriben en `profiles` (first-touch).
abstract final class AdAttributionStorage {
  static const _key = 'b2b_pending_ad_attribution';

  static Future<void> captureFromUri(Uri uri) async {
    final incoming = AdAttribution.fromUri(uri);
    if (incoming.isEmpty) return;
    final existing = await peek();
    final keep = AdAttribution.firstTouch(existing, incoming);
    if (keep.isEmpty) return;
    await _save(keep);
  }

  static Future<AdAttribution?> peek() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key)?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final attr = AdAttribution.fromJson(Map<String, dynamic>.from(decoded));
      return attr.isEmpty ? null : attr;
    } catch (_) {
      return null;
    }
  }

  static Future<AdAttribution?> consume() async {
    final attr = await peek();
    await clear();
    return attr;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _save(AdAttribution attr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(attr.toJson()));
  }
}
