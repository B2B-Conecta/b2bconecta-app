import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'motolink_pro_logo.dart';

/// AppBar blanco con logo, “Marketplace B2B” y campana con badge rojo.
class MotolinkAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MotolinkAppBar({
    super.key,
    this.onNotificationTap,
    this.extraActions,
  });

  final VoidCallback? onNotificationTap;
  final List<Widget>? extraActions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: const Row(
        children: [
          MotoLinkProLogo(height: 40),
          SizedBox(width: 10),
          Expanded(
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
                    color: AppColors.textPrimary,
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
                    color: AppColors.brand,
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
        child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ),
    );
  }
}
