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
    this.unreadNotifications = 0,
  });

  final VoidCallback? onNotificationTap;
  final List<Widget>? extraActions;
  final int unreadNotifications;

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
                  'MotoLink',
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
              if (unreadNotifications > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      unreadNotifications > 99
                          ? '99+'
                          : unreadNotifications.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
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
