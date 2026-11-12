import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/app/theme/theme_controller.dart';

/// Burbuja circular: menú con iconos **claro** / **oscuro**.
class ThemeModeBubble extends StatelessWidget {
  const ThemeModeBubble({super.key, this.compact = false, this.iconColor});

  final bool compact;

  /// En cabeceras branded (azul), forzar icono claro.
  final Color? iconColor;

  static const _modes = <ThemeMode>[ThemeMode.light, ThemeMode.dark];

  static IconData _icon(ThemeMode mode) => mode == ThemeMode.dark
      ? Icons.dark_mode_outlined
      : Icons.light_mode_outlined;

  static String _tooltip(ThemeMode mode) =>
      mode == ThemeMode.dark ? 'Oscuro' : 'Claro';

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    final size = compact ? 36.0 : 40.0;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final mode = controller.mode;
        final theme = B2BThemeExtension.of(context);
        final onBrand = Theme.of(context).colorScheme.onPrimary;
        return PopupMenuButton<ThemeMode>(
          tooltip: 'Claro / Oscuro',
          padding: EdgeInsets.zero,
          offset: const Offset(0, 44),
          constraints: const BoxConstraints(minWidth: 52, maxWidth: 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.border),
          ),
          color: theme.dialogSurface,
          onOpened: () => FocusManager.instance.primaryFocus?.unfocus(),
          onSelected: (m) {
            FocusManager.instance.primaryFocus?.unfocus();
            controller.setMode(m);
          },
          itemBuilder: (context) {
            final menuTheme = B2BThemeExtension.of(context);
            return [
              for (final m in _modes)
                PopupMenuItem<ThemeMode>(
                  value: m,
                  height: 48,
                  padding: EdgeInsets.zero,
                  child: Tooltip(
                    message: _tooltip(m),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mode == m
                              ? menuTheme.brandContainer
                              : Colors.transparent,
                          border: mode == m
                              ? Border.all(
                                  color: menuTheme.brand,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Icon(
                          _icon(m),
                          size: 20,
                          color: mode == m
                              ? menuTheme.brand
                              : menuTheme.textPrimary,
                        ),
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
              color: iconColor != null
                  ? onBrand.withOpacity(0.14)
                  : theme.inputFill,
              border: Border.all(
                color: iconColor != null
                    ? onBrand.withOpacity(0.28)
                    : theme.border,
                width: 1.2,
              ),
              boxShadow: iconColor != null
                  ? null
                  : [
                      BoxShadow(
                        color: theme.textPrimary.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(
              controller.currentIcon,
              size: compact ? 18 : 20,
              color: iconColor ?? theme.brand,
            ),
          ),
        );
      },
    );
  }
}
