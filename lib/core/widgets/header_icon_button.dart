import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final unread = count < 0 ? 0 : count;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
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
        child: Icon(
          icon,
          size: 22,
          color: iconColor ?? AppColors.textSecondary,
        ),
      ),
    );
  }
}
