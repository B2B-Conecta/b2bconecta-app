import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Preferencia de apariencia: **solo claro u oscuro**.
///
/// Actualiza [AppColors.brightness] de forma síncrona antes de notificar.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  Brightness get effectiveBrightness =>
      isDark ? Brightness.dark : Brightness.light;

  /// Compat: ya no observa el sistema.
  void attach() {
    _applyBrightness();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    // Migrar "system" → claro; solo se admiten light/dark.
    _mode = switch (raw) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    _applyBrightness();
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    final next = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    if (_mode == next) {
      _applyBrightness();
      notifyListeners();
      return;
    }
    _mode = next;
    _applyBrightness();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> toggle() =>
      setMode(isDark ? ThemeMode.light : ThemeMode.dark);

  void _applyBrightness() {
    AppColors.brightness = effectiveBrightness;
  }

  IconData get currentIcon =>
      isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined;
}
