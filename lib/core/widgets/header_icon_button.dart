import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/app/theme/theme_controller.dart';

/// Icono de cabecera con el mismo tamaño y la misma pastilla de conteo.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.count = 0,
    this.badgeColor,
    this.iconColor,
    this.iconWidget,
    this.size = slot,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int count;
  final Color? badgeColor;
  final Color? iconColor;
  final Widget? iconWidget;
  final Size size;

  static const slot = Size(40, 40);

  /// Color de icono de cabecera según el tema activo.
  static Color defaultIconColor(BuildContext context) {
    return B2BThemeExtension.of(context).textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final unread = count < 0 ? 0 : count;
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = B2BThemeExtension.of(context);
        final color = iconColor ?? defaultIconColor(context);
        return IconTheme(
          data: IconThemeData(color: color, size: 22),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            style: IconButton.styleFrom(
              foregroundColor: color,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              minimumSize: size,
              fixedSize: size,
            ),
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: badgeColor ?? theme.brand,
              largeSize: 16,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              label: Text(
                unread > 9 ? '9+' : '$unread',
                style: TextStyle(
                  color: theme.surfaceCard,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              child: iconWidget ?? Icon(icon, size: 22, color: color),
            ),
          ),
        );
      },
    );
  }
}
