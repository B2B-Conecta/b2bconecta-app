import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_dark_tokens.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

import 'lucide_icon.dart';

SnackBar appActionNotice({
  required Widget content,
  required String actionLabel,
  required VoidCallback onAction,
  EdgeInsetsGeometry? margin,
  Duration duration = const Duration(seconds: 4),
}) =>
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 10, 7, 10),
      duration: duration,
      content: content,
      action: SnackBarAction(label: actionLabel, onPressed: onAction),
    );

class AppNoticeMessage extends StatelessWidget {
  const AppNoticeMessage(this.message, {super.key, required this.icon});

  const AppNoticeMessage.error(this.message, {super.key})
      : icon = LucideGlyph.circleAlert;

  const AppNoticeMessage.success(this.message, {super.key})
      : icon = LucideGlyph.circleCheck;

  final String message;
  final LucideGlyph icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = switch (icon) {
      LucideGlyph.circleAlert => colors.error,
      LucideGlyph.circleCheck => colors.brightness == Brightness.dark
          ? AppDarkTokens.successFg
          : AppColors.successGreen,
      _ => DefaultTextStyle.of(context).style.color,
    };

    return Row(
      children: [
        LucideIcon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    );
  }
}
