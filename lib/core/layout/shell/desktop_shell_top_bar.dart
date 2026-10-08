import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/header_icon_button.dart';
import 'package:motolink_pro_app/core/widgets/messages_icon_button.dart';
import 'package:motolink_pro_app/core/widgets/theme_mode_bubble.dart';

/// Barra superior en shells de escritorio: acciones contextuales y notificaciones.
class DesktopShellTopBar extends StatelessWidget {
  const DesktopShellTopBar({
    super.key,
    required this.unreadNotifications,
    required this.onNotificationTap,
    this.onMessagesTap,
    this.unreadMessages = 0,
    this.trailingActions = const [],
  });

  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
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
              if (onMessagesTap != null)
                MessagesIconButton(
                  onPressed: onMessagesTap!,
                  unreadCount: unreadMessages,
                ),
              HeaderIconButton(
                tooltip: 'Notificaciones',
                onPressed: onNotificationTap,
                count: unreadNotifications,
                badgeColor: Colors.red,
                icon: unreadNotifications > 0
                    ? Icons.notifications
                    : Icons.notifications_none_outlined,
              ),
              const SizedBox(width: 4),
              const ThemeModeBubble(),
            ],
          ),
        ),
      ),
    );
  }
}
