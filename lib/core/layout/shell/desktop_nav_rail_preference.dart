import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia del menú lateral: expandido (etiquetas) vs colapsado (solo iconos).
abstract final class DesktopNavRailPreference {
  static const _keyExpanded = 'desktop_nav_rail_expanded';
  /// Legacy: antes «visible» ocultaba el rail por completo.
  static const _keyVisibleLegacy = 'desktop_nav_rail_visible';

  /// Por defecto expandido.
  static bool _expanded = true;
  static bool _loaded = false;

  static bool get expanded => _expanded;

  /// Alias de compatibilidad con lecturas antiguas.
  static bool get visible => _expanded;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_keyExpanded)) {
        _expanded = prefs.getBool(_keyExpanded) ?? true;
      } else if (prefs.containsKey(_keyVisibleLegacy)) {
        // Quienes «ocultaban» el menú pasan a rail colapsado (iconos).
        _expanded = prefs.getBool(_keyVisibleLegacy) ?? true;
      } else {
        _expanded = true;
      }
    } catch (_) {
      _expanded = true;
    }
    _loaded = true;
  }

  static Future<void> setExpanded(bool value) async {
    _expanded = value;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyExpanded, value);
    } catch (_) {
      // Preferencia en memoria aunque falle el disco.
    }
  }

  /// Compat: callers antiguos que usaban setVisible(false) ahora colapsan.
  static Future<void> setVisible(bool value) => setExpanded(value);
}
