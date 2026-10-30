import 'package:flutter/material.dart';

/// Paleta B2B Conecta — colores oficiales de marca:
/// - Azul oscuro `#0039A0`
/// - Tono claro `#0C47FA`
/// - Negro `#000000` / Blanco `#FFFFFF`
///
/// Claros/oscuros derivan de esos cuatro. Verde y ámbar se reservan para
/// estados funcionales y valoraciones, sin sustituir los colores de marca.
class AppColors {
  AppColors._();

  /// Sincronizado desde [MaterialApp] según [ThemeMode].
  static Brightness brightness = Brightness.light;

  static bool get _dark => brightness == Brightness.dark;

  /// Preferir esto en hojas visuales: se engancha a [Theme] y evita placeholders
  /// “congelados” al cambiar claro/oscuro sin refrescar.
  static Brightness brightnessOf(BuildContext context) =>
      Theme.of(context).brightness;

  static bool isDarkOf(BuildContext context) =>
      brightnessOf(context) == Brightness.dark;

  static Color surfaceTintedFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return dark
        ? Color.lerp(black, brandBlue, 0.20)!
        : Color.lerp(white, brandBlue, 0.04)!;
  }

  static Color textSecondaryFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return dark ? white.withOpacity(0.78) : black.withOpacity(0.62);
  }

  static Color textMutedFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return dark ? white.withOpacity(0.72) : black.withOpacity(0.48);
  }

  static Color photoFrameFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return dark ? Color.lerp(black, brandBlue, 0.14)! : white;
  }

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

  /// Enlace / icono de marca legible sobre superficies del tema actual.
  /// En oscuro usa el acento claro; en claro el azul cobalto.
  static Color get brandLink => _dark ? brandAccent : brandBlue;

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
  static Color get card => _dark ? Color.lerp(black, brandBlue, 0.30)! : white;

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

  /// Atención funcional y estrella de valoración; legibles en ambos temas.
  static const warningAmber = Color(0xFF946200);
  static const warningAmberOnDark = Color(0xFFF2C66D);

  /// Superficies pastel adaptadas (evita blanco/ámbar claro + texto blanco).
  static Color get warningSurface => _dark
      ? Color.lerp(black, warningAmberOnDark, 0.18)!
      : const Color(0xFFFFF8E1);

  static Color get infoSurface => _dark
      ? Color.lerp(black, brandAccent, 0.18)!
      : Color.lerp(white, brandBlue, 0.08)!;

  static Color get successSurface => _dark
      ? Color.lerp(black, successGreen, 0.22)!
      : const Color(0xFFE8F5E9);

  static Color get tealSurface => _dark
      ? Color.lerp(black, const Color(0xFF4DB6AC), 0.20)!
      : const Color(0xFFE0F2F1);

  /// Si [color] es un pastel claro en modo oscuro, lo sustituye por [fallback].
  static Color resolveSurface(Color? color, {Color? fallback}) {
    final fb = fallback ?? surfaceTinted;
    if (color == null) return fb;
    if (_dark && color.computeLuminance() > 0.65) return fb;
    return color;
  }
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

SnackBarThemeData _snackBarTheme({
  required Color background,
  required Color foreground,
  required Color action,
}) {
  return SnackBarThemeData(
    backgroundColor: background,
    contentTextStyle: TextStyle(
      color: foreground,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
    actionTextColor: action,
    disabledActionTextColor: foreground.withOpacity(0.45),
    behavior: SnackBarBehavior.floating,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
  );
}

ThemeData buildAppTheme() {
  const primary = AppColors.brandBlue;
  const accent = AppColors.brandAccent;
  final snackBg = Color.lerp(AppColors.black, primary, 0.22)!;
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
      inverseSurface: snackBg,
      onInverseSurface: AppColors.white,
    ),
    snackBarTheme: _snackBarTheme(
      background: snackBg,
      foreground: AppColors.white,
      action: accent,
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
    dividerTheme:
        DividerThemeData(color: primary.withOpacity(0.12), thickness: 1),
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
  // Elevado respecto al scaffold: se lee bien sin el flash blanco de inverseSurface.
  final snackBg = Color.lerp(AppColors.black, brand, 0.48)!;
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
      inverseSurface: snackBg,
      onInverseSurface: AppColors.white,
    ),
    snackBarTheme: _snackBarTheme(
      background: snackBg,
      foreground: AppColors.white,
      action: primary,
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
