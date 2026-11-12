import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';

/// Context-dependent colors also rebuild constant children when the theme changes.
class OrderListColors {
  OrderListColors.of(BuildContext context)
      : dark = Theme.of(context).brightness == Brightness.dark,
        theme = B2BThemeExtension.of(context);

  final bool dark;
  final B2BThemeExtension theme;

  Color get background => theme.background;
  Color get ink => theme.textPrimary;
  Color get secondary => theme.textSecondary;
  Color get accent => theme.brand;
  Color get surface => theme.surfaceCard;
  Color get soft => theme.surfaceSubtle;
  Color get border => theme.border;

  /// Foreground on filled accent chips.
  Color get onAccent => theme.surfaceCard;

  Color get pendingAccent =>
      dark ? AppColors.warningAmberOnDark : AppColors.warningAmber;
  Color get pendingSurface =>
      Color.alphaBlend(pendingAccent.withOpacity(dark ? .10 : .045), surface);
}
