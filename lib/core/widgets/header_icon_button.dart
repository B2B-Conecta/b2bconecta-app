import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
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
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int count;
  final Color? badgeColor;
  final Color? iconColor;

  static const slot = Size(40, 40);

  /// Color legible en la barra superior según el modo elegido (no [Theme.of],
  /// que a veces va un frame atrasado respecto a [AppColors] al cambiar tono).
  static Color defaultIconColor() {
    final dark = ThemeController.instance.isDark;
    return dark
        ? AppColors.white.withOpacity(0.88)
        : AppColors.black.withOpacity(0.72);
  }

  @override
  Widget build(BuildContext context) {
    final unread = count < 0 ? 0 : count;
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final color = iconColor ?? defaultIconColor();
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
              minimumSize: slot,
              fixedSize: slot,
            ),
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: badgeColor ?? AppColors.brand,
              largeSize: 16,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              label: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
          ),
        );
      },
    );
  }
}
