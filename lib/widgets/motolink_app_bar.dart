import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'motolink_pro_logo.dart';

/// Altura del logo en AppBar: importadores (compacto) vs aliados (más visible).
abstract final class MotolinkAppBarLogoSizes {
  static const double importador = 40;
  static const double aliado = 52;
}

/// AppBar blanco con logo, “Marketplace B2B” y campana con badge (naranja marca).
class MotolinkAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MotolinkAppBar({
    super.key,
    this.onNotificationTap,
    this.extraActions,
    this.logoHeight = MotolinkAppBarLogoSizes.importador,
  });

  final VoidCallback? onNotificationTap;
  final List<Widget>? extraActions;

  /// Alto del [MotoLinkProLogo] (p. ej. [MotolinkAppBarLogoSizes.aliado] para talleres).
  final double logoHeight;

  @override
  Size get preferredSize =>
      Size.fromHeight(math.max(kToolbarHeight, logoHeight + 10));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: math.max(kToolbarHeight, logoHeight + 8),
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          MotoLinkProLogo(height: logoHeight),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MotoLink Pro',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.brandBlue,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Marketplace B2B',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ...?extraActions,
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined),
                color: AppColors.textSecondary,
                onPressed: onNotificationTap,
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.brandOrange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.brandBlue.withOpacity(0.12),
        ),
      ),
    );
  }
}
