import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_dark_tokens.dart';

/// Tokens semánticos B2B Conecta (claro / oscuro) vía [ThemeData.extensions].
@immutable
class B2BThemeExtension extends ThemeExtension<B2BThemeExtension> {
  const B2BThemeExtension({
    required this.background,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.sidebarBg,
    required this.sidebarBorder,
    required this.sidebarLabel,
    required this.sidebarMuted,
    required this.sidebarActiveFill,
    required this.sidebarActiveFg,
    required this.sidebarFooterBg,
    required this.sidebarFooterBorder,
    required this.tableHeaderBg,
    required this.tableRowEven,
    required this.tableRowOdd,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.inputFill,
    required this.dialogSurface,
    required this.brand,
    required this.brandContainer,
    required this.successBg,
    required this.successFg,
  });

  final Color background;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color sidebarBg;
  final Color sidebarBorder;
  final Color sidebarLabel;
  final Color sidebarMuted;
  final Color sidebarActiveFill;
  final Color sidebarActiveFg;
  final Color sidebarFooterBg;
  final Color sidebarFooterBorder;
  final Color tableHeaderBg;
  final Color tableRowEven;
  final Color tableRowOdd;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderStrong;
  final Color inputFill;
  final Color dialogSurface;
  final Color brand;
  final Color brandContainer;
  /// Fondos de estado positivo (p. ej. Entregado y pagado).
  final Color successBg;
  final Color successFg;

  /// Alias: filas / cajas sutiles.
  Color get surfaceSubtle => tableRowOdd;

  /// Alias: divisores y bordes ligeros.
  Color get borderSubtle => border;

  static const light = B2BThemeExtension(
    background: Color(0xFFF8FAFC),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    sidebarBg: Color(0xFFFFFFFF),
    sidebarBorder: Color(0xFFE2E8F0),
    sidebarLabel: Color(0xFF334155),
    sidebarMuted: Color(0xFF64748B),
    sidebarActiveFill: Color(0xFFEFF6FF),
    sidebarActiveFg: Color(0xFF2563EB),
    sidebarFooterBg: Color(0xFFE2E8F0),
    sidebarFooterBorder: Color(0xFFCBD5E1),
    tableHeaderBg: Color(0xFFF8FAFC),
    tableRowEven: Color(0xFFFFFFFF),
    tableRowOdd: Color(0xFFF8FAFC),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    inputFill: Color(0xFFF8FAFC),
    dialogSurface: Color(0xFFFFFFFF),
    brand: Color(0xFF2563EB),
    brandContainer: Color(0xFFEFF6FF),
    successBg: Color(0xFFDCFCE7),
    successFg: Color(0xFF16A34A),
  );

  static const dark = B2BThemeExtension(
    background: AppDarkTokens.background,
    surfaceCard: AppDarkTokens.surface,
    surfaceElevated: AppDarkTokens.surfaceElevated,
    sidebarBg: AppDarkTokens.surface,
    sidebarBorder: AppDarkTokens.border,
    sidebarLabel: AppDarkTokens.textPrimary,
    sidebarMuted: AppDarkTokens.textSecondary,
    sidebarActiveFill: Color(0x2E3B82F6), // Blue 500 @ ~18%
    sidebarActiveFg: Color(0xFFFFFFFF),
    sidebarFooterBg: AppDarkTokens.surfaceElevated,
    sidebarFooterBorder: AppDarkTokens.borderStrong,
    tableHeaderBg: AppDarkTokens.surfaceElevated,
    tableRowEven: AppDarkTokens.surface,
    tableRowOdd: AppDarkTokens.surfaceSubtle,
    textPrimary: AppDarkTokens.textPrimary,
    textSecondary: AppDarkTokens.textSecondary,
    textMuted: AppDarkTokens.textMuted,
    border: AppDarkTokens.border,
    borderStrong: AppDarkTokens.borderStrong,
    inputFill: AppDarkTokens.fieldFill,
    dialogSurface: AppDarkTokens.surfaceElevated,
    brand: AppDarkTokens.brand,
    brandContainer: AppDarkTokens.brandContainer,
    successBg: AppDarkTokens.successPill,
    successFg: AppDarkTokens.successFg,
  );

  static B2BThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<B2BThemeExtension>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  B2BThemeExtension copyWith({
    Color? background,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? sidebarBg,
    Color? sidebarBorder,
    Color? sidebarLabel,
    Color? sidebarMuted,
    Color? sidebarActiveFill,
    Color? sidebarActiveFg,
    Color? sidebarFooterBg,
    Color? sidebarFooterBorder,
    Color? tableHeaderBg,
    Color? tableRowEven,
    Color? tableRowOdd,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderStrong,
    Color? inputFill,
    Color? dialogSurface,
    Color? brand,
    Color? brandContainer,
    Color? successBg,
    Color? successFg,
  }) {
    return B2BThemeExtension(
      background: background ?? this.background,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      sidebarLabel: sidebarLabel ?? this.sidebarLabel,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      sidebarActiveFill: sidebarActiveFill ?? this.sidebarActiveFill,
      sidebarActiveFg: sidebarActiveFg ?? this.sidebarActiveFg,
      sidebarFooterBg: sidebarFooterBg ?? this.sidebarFooterBg,
      sidebarFooterBorder: sidebarFooterBorder ?? this.sidebarFooterBorder,
      tableHeaderBg: tableHeaderBg ?? this.tableHeaderBg,
      tableRowEven: tableRowEven ?? this.tableRowEven,
      tableRowOdd: tableRowOdd ?? this.tableRowOdd,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      inputFill: inputFill ?? this.inputFill,
      dialogSurface: dialogSurface ?? this.dialogSurface,
      brand: brand ?? this.brand,
      brandContainer: brandContainer ?? this.brandContainer,
      successBg: successBg ?? this.successBg,
      successFg: successFg ?? this.successFg,
    );
  }

  @override
  B2BThemeExtension lerp(ThemeExtension<B2BThemeExtension>? other, double t) {
    if (other is! B2BThemeExtension) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return B2BThemeExtension(
      background: l(background, other.background),
      surfaceCard: l(surfaceCard, other.surfaceCard),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      sidebarBg: l(sidebarBg, other.sidebarBg),
      sidebarBorder: l(sidebarBorder, other.sidebarBorder),
      sidebarLabel: l(sidebarLabel, other.sidebarLabel),
      sidebarMuted: l(sidebarMuted, other.sidebarMuted),
      sidebarActiveFill: l(sidebarActiveFill, other.sidebarActiveFill),
      sidebarActiveFg: l(sidebarActiveFg, other.sidebarActiveFg),
      sidebarFooterBg: l(sidebarFooterBg, other.sidebarFooterBg),
      sidebarFooterBorder: l(sidebarFooterBorder, other.sidebarFooterBorder),
      tableHeaderBg: l(tableHeaderBg, other.tableHeaderBg),
      tableRowEven: l(tableRowEven, other.tableRowEven),
      tableRowOdd: l(tableRowOdd, other.tableRowOdd),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      inputFill: l(inputFill, other.inputFill),
      dialogSurface: l(dialogSurface, other.dialogSurface),
      brand: l(brand, other.brand),
      brandContainer: l(brandContainer, other.brandContainer),
      successBg: l(successBg, other.successBg),
      successFg: l(successFg, other.successFg),
    );
  }
}
