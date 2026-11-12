import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/app_scaffold_messenger.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Toast flotante para acciones CRUD del panel admin.
abstract final class AdminCrudToast {
  static void success(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      glyph: LucideGlyph.circleCheck,
      success: true,
      duration: duration,
    );
  }

  static void error(
    BuildContext? context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message: message,
      glyph: LucideGlyph.circleAlert,
      success: false,
      duration: duration,
    );
  }

  static void _show(
    BuildContext? context, {
    required String message,
    required LucideGlyph glyph,
    required bool success,
    required Duration duration,
  }) {
    final messenger = scaffoldMessengerKey.currentState ??
        (context != null ? ScaffoldMessenger.maybeOf(context) : null);
    if (messenger == null) return;

    final theme = context != null
        ? B2BThemeExtension.of(context)
        : B2BThemeExtension.dark;
    final glyphColor = success ? theme.successFg : const Color(0xFFEF4444);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.surfaceElevated,
          elevation: 6,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.borderStrong),
          ),
          content: Row(
            children: [
              LucideIcon(glyph, size: 20, color: glyphColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
