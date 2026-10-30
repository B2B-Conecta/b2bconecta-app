import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de visibilidad del menú lateral en shells de escritorio web.
abstract final class DesktopNavRailPreference {
  static const _key = 'desktop_nav_rail_visible';

  /// Por defecto visible.
  static bool _visible = true;
  static bool _loaded = false;

  static bool get visible => _visible;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _visible = prefs.getBool(_key) ?? true;
    } catch (_) {
      _visible = true;
    }
    _loaded = true;
  }

  static Future<void> setVisible(bool value) async {
    _visible = value;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {
      // Preferencia en memoria aunque falle el disco.
    }
  }
}
