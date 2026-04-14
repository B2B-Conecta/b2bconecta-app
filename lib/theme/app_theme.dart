import 'package:flutter/material.dart';

/// Tokens de diseño MotoLink (paleta derivada del logo oficial: azul + naranja).
class AppColors {
  AppColors._();

  /// Azul cobalto / marca (títulos, énfasis, iconos de cabecera).
  static const brandBlue = Color(0xFF1565C0);

  /// Naranja acción (CTA, chips activos, precios, badge, tabs seleccionadas).
  static const brandOrange = Color(0xFFFF6D00);

  /// Alias histórico: mismo que [brandOrange] (botones, foco, acentos de acción).
  static const brand = brandOrange;

  /// Azul muy claro (contenedores secundarios, chips M3).
  static const brandBlueContainer = Color(0xFFE3EEF8);

  /// Fondo de pantalla (gris-azulado, un poco más azul que antes).
  static const background = Color(0xFFF0F4FA);

  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);

  /// Campos y superficies suaves (tinte azul respecto al gris neutro).
  static const fieldFill = Color(0xFFE8EEF5);

  /// AppBar, bottom nav y tarjetas sobre fondo (blanco con tinte azul logo).
  static const surfaceTinted = Color(0xFFF7FAFC);
  static const successGreen = Color(0xFF2E7D32);
}

class AppDecorations {
  AppDecorations._();

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static BorderRadius get radius12 => BorderRadius.circular(12);
}

ThemeData buildAppTheme() {
  const accent = AppColors.brandOrange;
  const blue = AppColors.brandBlue;
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: accent,
      onPrimary: Colors.white,
      secondary: blue,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.brandBlueContainer,
      onSecondaryContainer: Color(0xFF0D47A1),
      surface: AppColors.surfaceTinted,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceTinted,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Color(0x331565C0),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceTinted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIconColor: AppColors.textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.12),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceTinted,
      selectedItemColor: AppColors.brandOrange,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
