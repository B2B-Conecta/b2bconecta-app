import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Context-dependent colors also rebuild constant children when the theme changes.
class OrderListColors {
  OrderListColors.of(BuildContext context)
      : dark = Theme.of(context).brightness == Brightness.dark,
        background = Theme.of(context).scaffoldBackgroundColor;

  final bool dark;
  final Color background;
  Color get ink => dark ? AppColors.white : AppColors.black;
  Color get secondary =>
      Color.alphaBlend(ink.withOpacity(dark ? .78 : .64), background);
  Color get accent => dark
      ? Color.lerp(AppColors.brandBlue, AppColors.white, .72)!
      : AppColors.brandBlue;
  Color get surface => dark
      ? Color.lerp(AppColors.black, AppColors.brandBlue, .18)!
      : AppColors.white;
  Color get soft => dark
      ? Color.lerp(AppColors.black, AppColors.brandBlue, .26)!
      : Color.lerp(AppColors.white, AppColors.brandBlue, .035)!;
  Color get border => ink.withOpacity(dark ? .15 : .085);
}
