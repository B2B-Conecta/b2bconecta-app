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

  Color get detailSurface => dark ? soft : const Color(0xFFEEF1F6);
  Color get pendingAccent =>
      dark ? AppColors.warningAmberOnDark : AppColors.warningAmber;
  Color get pendingSurface =>
      Color.alphaBlend(pendingAccent.withOpacity(dark ? .10 : .045), surface);

  Color statusForeground(Color preferred) {
    // Compact badges use a 14% tint over both neutral and pending cards.
    final backdrops = [
      surface,
      soft,
      pendingSurface,
      if (!dark) ...[const Color(0xFFF2F4F7), const Color(0xFFFFF5E3)],
    ];
    final target = dark ? Colors.white : Colors.black;
    for (var step = 0; step <= 20; step++) {
      final foreground = Color.lerp(preferred, target, step / 20)!;
      final foregroundLuminance = foreground.computeLuminance();
      final readable = backdrops.every((backdrop) {
        final background =
            Color.alphaBlend(foreground.withOpacity(.14), backdrop);
        final backgroundLuminance = background.computeLuminance();
        final lighter = foregroundLuminance > backgroundLuminance
            ? foregroundLuminance
            : backgroundLuminance;
        final darker = foregroundLuminance < backgroundLuminance
            ? foregroundLuminance
            : backgroundLuminance;
        return (lighter + .05) / (darker + .05) >= 4.5;
      });
      if (readable) return foreground;
    }
    return target;
  }
}
