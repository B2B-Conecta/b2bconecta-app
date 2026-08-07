import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Burbuja circular: menú con **solo Claro y Oscuro** (sin sistema).
/// Al elegir, [ThemeController] cambia la estética de toda la app.
class ThemeModeBubble extends StatelessWidget {
  const ThemeModeBubble({super.key, this.compact = false});

  final bool compact;

  static const _modes = <ThemeMode>[ThemeMode.light, ThemeMode.dark];

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    final size = compact ? 36.0 : 40.0;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final mode = controller.mode;
        return PopupMenuButton<ThemeMode>(
          tooltip: 'Claro / Oscuro',
          padding: EdgeInsets.zero,
          offset: const Offset(0, 44),
          constraints: const BoxConstraints(minWidth: 52, maxWidth: 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.borderSubtle),
          ),
          color: AppColors.card,
          onSelected: (m) {
            // Ignorar async: el notify es síncrono al inicio de setMode.
            controller.setMode(m);
          },
          itemBuilder: (context) {
            return [
              for (final m in _modes)
                PopupMenuItem<ThemeMode>(
                  value: m,
                  height: 48,
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mode == m
                            ? AppColors.brandAccent.withOpacity(0.16)
                            : Colors.transparent,
                        border: mode == m
                            ? Border.all(
                                color: AppColors.brandAccent,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Icon(
                        m == ThemeMode.dark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        size: 20,
                        color: mode == m
                            ? AppColors.brandAccent
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ];
          },
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.fieldFill,
              border: Border.all(color: AppColors.borderSubtle, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              controller.currentIcon,
              size: compact ? 18 : 20,
              color: controller.isDark
                  ? AppColors.brandAccent
                  : AppColors.brandBlue,
            ),
          ),
        );
      },
    );
  }
}
