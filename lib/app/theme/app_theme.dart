import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_dark_tokens.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';

/// Paleta B2B Conecta — claro + oscuro (WCAG 2.1 AA).
///
/// **Claro:** azul marca `#0039A0` / acento `#0C47FA` (legado producto).
/// **Oscuro:** tokens slate + Blue 500 — ver [AppDarkTokens] y
/// `docs/DARK_MODE_STYLE_GUIDE.md`.
///
/// El panel admin (Cuentas, Ajustes) también usa [AdminUsersChrome], que
/// reacciona a [brightness] / [AppDarkTokens] en modo oscuro.
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
    return dark ? AppDarkTokens.surfaceElevated : Color.lerp(white, brandBlue, 0.04)!;
  }

  static Color textSecondaryFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return dark ? AppDarkTokens.textSecondary : black.withOpacity(0.62);
  }

  static Color textMutedFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return dark ? AppDarkTokens.textMuted : black.withOpacity(0.48);
  }

  static Color photoFrameFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return dark ? AppDarkTokens.surfaceSubtle : white;
  }

  /// Azul oscuro de marca (referencia oficial — modo claro / logo).
  static const brandBlue = Color(0xFF0039A0);

  /// Tono claro / acento (referencia oficial — modo claro).
  static const brandAccent = Color(0xFF0C47FA);
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);

  /// CTA / marca en contextos `const` (= azul cobalto del logo).
  /// En UI reactiva a tema preferir [brandLink] o `Theme.colorScheme.primary`
  /// (en oscuro: [AppDarkTokens.brand] Blue 500).
  static const brand = brandBlue;

  /// Compat: mismo que [brand].
  static const brandOrange = brand;

  /// Enlace / icono de marca legible sobre superficies del tema actual.
  static Color get brandLink => _dark ? AppDarkTokens.brand : brandBlue;

  /// Superficie suave de acento.
  static Color get brandBlueContainer =>
      _dark ? AppDarkTokens.brandContainer : Color.lerp(white, brandBlue, 0.08)!;

  static Color get background =>
      _dark ? AppDarkTokens.background : white;

  static Color get textPrimary =>
      _dark ? AppDarkTokens.textPrimary : black;

  /// Secundario con contraste AA en oscuro (≈ 5.9:1).
  static Color get textSecondary =>
      _dark ? AppDarkTokens.textSecondary : black.withOpacity(0.62);

  /// Terciario / hints.
  static Color get textMuted =>
      _dark ? AppDarkTokens.textMuted : black.withOpacity(0.48);

  /// Relleno de inputs.
  static Color get fieldFill =>
      _dark ? AppDarkTokens.fieldFill : Color.lerp(white, brandBlue, 0.07)!;

  static Color get surfaceTinted =>
      _dark ? AppDarkTokens.surfaceElevated : Color.lerp(white, brandBlue, 0.04)!;

  /// Tarjetas / paneles elevados sobre el fondo.
  static Color get card => _dark ? AppDarkTokens.surface : white;

  /// Superficie elevada (modales / sheets) en dark; en claro = card.
  static Color get cardElevated =>
      _dark ? AppDarkTokens.surfaceElevated : white;

  /// Zebra / filas alternas.
  static Color get zebra =>
      _dark ? AppDarkTokens.surfaceSubtle : const Color(0xFFF8FAFC);

  static Color get borderSubtle =>
      _dark ? AppDarkTokens.borderStrong : brandBlue.withOpacity(0.18);

  static Color get divider =>
      _dark ? AppDarkTokens.border : brandBlue.withOpacity(0.12);

  /// Placeholder / hint legible sobre [fieldFill] en claro y oscuro.
  static TextStyle get hintStyle => TextStyle(
        color: textMuted,
        fontWeight: FontWeight.w500,
      );

  /// Éxito funcional (modo claro).
  static const successGreen = Color(0xFF2E7D32);

  /// Éxito adaptado al tema (texto / iconos).
  static Color get successForeground =>
      _dark ? AppDarkTokens.successFg : successGreen;

  /// Atención funcional y estrella de valoración.
  static const warningAmber = Color(0xFF946200);
  static const warningAmberOnDark = Color(0xFFFBBF24);

  static Color get warningForeground =>
      _dark ? AppDarkTokens.warningFg : warningAmber;

  static Color get dangerForeground =>
      _dark ? AppDarkTokens.dangerFg : const Color(0xFFDC2626);

  static Color get dangerSolid =>
      _dark ? AppDarkTokens.dangerSolid : const Color(0xFFEF4444);

  /// Superficies pastel adaptadas (evita blanco/ámbar claro + texto blanco).
  static Color get warningSurface =>
      _dark ? AppDarkTokens.warningPill : const Color(0xFFFFF8E1);

  static Color get infoSurface =>
      _dark ? AppDarkTokens.brandContainer : Color.lerp(white, brandBlue, 0.08)!;

  static Color get successSurface =>
      _dark ? AppDarkTokens.successPill : const Color(0xFFE8F5E9);

  static Color get dangerSurface =>
      _dark ? AppDarkTokens.dangerPill : const Color(0xFFFEE2E2);

  static Color get tealSurface => _dark
      ? Color.lerp(AppDarkTokens.surface, const Color(0xFF4DB6AC), 0.20)!
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
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: AppDecorations.radius12,
      side: BorderSide(color: foreground.withOpacity(0.18)),
    ),
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
    extensions: const <ThemeExtension<dynamic>>[B2BThemeExtension.light],
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
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
      error: const Color(0xFFDC2626),
      onError: AppColors.white,
    ),
    snackBarTheme: _snackBarTheme(
      background: primary,
      foreground: AppColors.white,
      action: const Color(0xFFE0EBFF),
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

/// Tema oscuro B2B Conecta — [AppDarkTokens], toggle Sol/Luna ([ThemeController]).
ThemeData buildAppDarkTheme() {
  const primary = AppDarkTokens.brand;
  const scaffold = AppDarkTokens.background;
  const surface = AppDarkTokens.surface;
  const elevated = AppDarkTokens.surfaceElevated;
  const field = AppDarkTokens.fieldFill;
  const onSurface = AppDarkTokens.textPrimary;
  const onVariant = AppDarkTokens.textSecondary;
  const outline = AppDarkTokens.borderStrong;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    extensions: const <ThemeExtension<dynamic>>[B2BThemeExtension.dark],
    scaffoldBackgroundColor: scaffold,
    colorScheme: ColorScheme.dark(
      primary: primary,
      onPrimary: onSurface,
      secondary: AppDarkTokens.brandBase,
      onSecondary: onSurface,
      secondaryContainer: AppDarkTokens.brandContainer,
      onSecondaryContainer: onSurface,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onVariant,
      surfaceContainerHighest: elevated,
      outline: outline,
      inverseSurface: elevated,
      onInverseSurface: onSurface,
      error: AppDarkTokens.dangerSolid,
      onError: onSurface,
    ),
    snackBarTheme: _snackBarTheme(
      background: elevated,
      foreground: onSurface,
      action: primary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardTheme(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppDarkTokens.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppDarkTokens.border,
      thickness: 1,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppDarkTokens.borderStrong),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: elevated,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: elevated,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppDarkTokens.sidebar,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppDarkTokens.textMuted),
      labelStyle: const TextStyle(color: AppDarkTokens.textSecondary),
      prefixIconColor: AppDarkTokens.textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onSurface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onSurface,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: AppDarkTokens.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    cardColor: surface,
    dividerColor: AppDarkTokens.border,
  );
}
