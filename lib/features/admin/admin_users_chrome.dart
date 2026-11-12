import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/app/theme/theme_controller.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Superficie compartida del hub Usuarios / ajustes admin.
///
/// Prefiere [B2BThemeExtension] vía [of]; los getters estáticos siguen
/// [ThemeController] (no un [AppColors.brightness] desfasado).
abstract final class AdminUsersChrome {
  static bool get _dark => ThemeController.instance.isDark;

  static B2BThemeExtension get _tokens =>
      _dark ? B2BThemeExtension.dark : B2BThemeExtension.light;

  static B2BThemeExtension of(BuildContext context) =>
      B2BThemeExtension.of(context);

  static Color get border => _tokens.borderStrong;

  static Color get titleColor => _tokens.textPrimary;

  static Color get muted => _tokens.textSecondary;

  static Color get brand => _tokens.brand;

  /// Fila impar (zebra).
  static Color get zebra => _tokens.tableRowOdd;

  /// Fila par.
  static Color get rowEven => _tokens.tableRowEven;

  static Color get tableHeaderBg => _tokens.tableHeaderBg;

  static Color get inputFill => _tokens.inputFill;

  /// Tarjetas sobre el fondo.
  static Color get cardColor =>
      _dark ? _tokens.surfaceElevated : _tokens.surfaceCard;

  /// Superficie de modales / sheets.
  static Color get dialogSurface => _tokens.dialogSurface;

  static Color get glyphTile => _tokens.brandContainer;

  static const radius = 12.0;
  static const sheetRadius = 16.0;

  static BoxDecoration card({double radius = radius}) => BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: _tokens.textPrimary.withOpacity(_dark ? 0.28 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );

  static InputDecoration field({
    required String label,
    String? hint,
    String? errorText,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder outline([Color? c, double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c ?? border, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
      floatingLabelStyle: TextStyle(color: brand, fontWeight: FontWeight.w700),
      hintStyle: TextStyle(color: muted),
      filled: true,
      fillColor: inputFill,
      isDense: true,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: outline(),
      enabledBorder: outline(),
      focusedBorder: outline(brand, 1.4),
      errorBorder: outline(const Color(0xFFEF4444)),
      focusedErrorBorder: outline(const Color(0xFFEF4444), 1.4),
    );
  }

  static Widget sectionHeader({
    required String title,
    required String subtitle,
    LucideGlyph? glyph,
    List<Widget>? actions,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (glyph != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: glyphTile,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: LucideIcon(glyph, size: 20, color: brand),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          if (actions != null) ...actions,
        ],
      ),
    );
  }
}
