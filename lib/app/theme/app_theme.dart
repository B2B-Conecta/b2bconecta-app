import 'package:flutter/material.dart';

/// Paleta B2B Conecta — colores oficiales de marca:
/// - Azul oscuro `#0039A0`
/// - Tono claro `#0C47FA`
/// - Negro `#000000` / Blanco `#FFFFFF`
///
/// Claros/oscuros derivan de esos cuatro (opacidad o mezcla), sin grises ni naranjas ajenos.
class AppColors {
  AppColors._();

  /// Sincronizado desde [MaterialApp] según [ThemeMode].
  static Brightness brightness = Brightness.light;

  static bool get _dark => brightness == Brightness.dark;

  /// Azul oscuro de marca (referencia oficial).
  static const brandBlue = Color(0xFF0039A0);

  /// Tono claro / acento (referencia oficial).
  static const brandAccent = Color(0xFF0C47FA);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  /// CTA primario (= azul cobalto del logo).
  static const brand = brandBlue;

  /// Compat: mismo que [brand].
  static const brandOrange = brand;

  /// Superficie suave: blanco + tinte azul marca (claro) / azul sobre negro (oscuro).
  static Color get brandBlueContainer => _dark
      ? Color.lerp(black, brandBlue, 0.35)!
      : Color.lerp(white, brandBlue, 0.08)!;

  static Color get background =>
      _dark ? Color.lerp(black, brandBlue, 0.10)! : white;

  static Color get textPrimary => _dark ? white : black;

  /// Secundario con contraste usable (WCAG-ish) en claro y oscuro.
  static Color get textSecondary =>
      _dark ? white.withOpacity(0.78) : black.withOpacity(0.62);

  /// Terciario / hints (placeholders); aún legible sobre campos.
  static Color get textMuted =>
      _dark ? white.withOpacity(0.72) : black.withOpacity(0.48);

  /// Relleno de inputs: más hundido que [card] para que se distinga en ambos modos.
  static Color get fieldFill => _dark
      ? Color.lerp(black, brandBlue, 0.14)!
      : Color.lerp(white, brandBlue, 0.07)!;

  static Color get surfaceTinted => _dark
      ? Color.lerp(black, brandBlue, 0.20)!
      : Color.lerp(white, brandBlue, 0.04)!;

  /// Tarjetas / paneles elevados sobre el fondo.
  static Color get card => _dark
      ? Color.lerp(black, brandBlue, 0.30)!
      : white;

  static Color get borderSubtle =>
      _dark ? white.withOpacity(0.28) : brandBlue.withOpacity(0.18);

  static Color get divider =>
      _dark ? white.withOpacity(0.16) : brandBlue.withOpacity(0.12);

  /// Placeholder / hint legible sobre [fieldFill] en claro y oscuro.
  static TextStyle get hintStyle => TextStyle(
        color: textMuted,
        fontWeight: FontWeight.w500,
      );

  /// Éxito funcional (no es color de marca; se mantiene para estados OK).
  static const successGreen = Color(0xFF2E7D32);
}

class AppDecorations {
  AppDecorations._();

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AppColors.black.withOpacity(AppColors._dark ? 0.45 : 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static BorderRadius get radius12 => BorderRadius.circular(12);
}

ThemeData buildAppTheme() {
  const primary = AppColors.brandBlue;
  const accent = AppColors.brandAccent;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.white,
    colorScheme: ColorScheme.light(
      primary: primary,
      onPrimary: AppColors.white,
      secondary: accent,
      onSecondary: AppColors.white,
      secondaryContainer: Color.lerp(AppColors.white, primary, 0.10)!,
      onSecondaryContainer: primary,
      surface: AppColors.white,
      onSurface: AppColors.black,
      outline: primary.withOpacity(0.18),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: primary.withOpacity(0.08),
      titleTextStyle: const TextStyle(
        color: AppColors.black,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardTheme(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primary.withOpacity(0.10)),
      ),
    ),
    dividerTheme: DividerThemeData(color: primary.withOpacity(0.12), thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color.lerp(AppColors.white, primary, 0.05)!,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: AppColors.black.withOpacity(0.48)),
      labelStyle: TextStyle(color: AppColors.black.withOpacity(0.62)),
      prefixIconColor: AppColors.black.withOpacity(0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary.withOpacity(0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary.withOpacity(0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: AppColors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: primary,
      unselectedItemColor: AppColors.black.withOpacity(0.55),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}

ThemeData buildAppDarkTheme() {
  const primary = AppColors.brandAccent;
  const brand = AppColors.brandBlue;
  final scaffold = Color.lerp(AppColors.black, brand, 0.10)!;
  final surface = Color.lerp(AppColors.black, brand, 0.22)!;
  final field = Color.lerp(AppColors.black, brand, 0.28)!;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: scaffold,
    colorScheme: ColorScheme.dark(
      primary: primary,
      onPrimary: AppColors.white,
      secondary: brand,
      onSecondary: AppColors.white,
      secondaryContainer: Color.lerp(AppColors.black, brand, 0.40)!,
      onSecondaryContainer: AppColors.white,
      surface: surface,
      onSurface: AppColors.white,
      onSurfaceVariant: AppColors.white.withOpacity(0.78),
      outline: AppColors.white.withOpacity(0.22),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: primary.withOpacity(0.12),
      titleTextStyle: const TextStyle(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardTheme(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.white.withOpacity(0.18)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.white.withOpacity(0.16),
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: AppColors.white.withOpacity(0.72)),
      labelStyle: TextStyle(color: AppColors.white.withOpacity(0.78)),
      prefixIconColor: AppColors.white.withOpacity(0.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.white.withOpacity(0.22)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.white.withOpacity(0.22)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: AppColors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: AppColors.white.withOpacity(0.65),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    cardColor: surface,
    dividerColor: AppColors.white.withOpacity(0.16),
  );
}
