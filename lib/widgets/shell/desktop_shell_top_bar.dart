import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../theme_mode_bubble.dart';

/// Barra superior en shells de escritorio: acciones contextuales y notificaciones.
class DesktopShellTopBar extends StatelessWidget {
  const DesktopShellTopBar({
    super.key,
    required this.unreadNotifications,
    required this.onNotificationTap,
    this.trailingActions = const [],
  });

  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTinted,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            children: [
              const Spacer(),
              ...trailingActions,
              const SizedBox(width: 4),
              const ThemeModeBubble(),
              const SizedBox(width: 4),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notificaciones',
                    onPressed: onNotificationTap,
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadNotifications > 99
                              ? '99+'
                              : '$unreadNotifications',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
