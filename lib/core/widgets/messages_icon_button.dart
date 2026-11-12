import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'header_icon_button.dart';
import 'lucide_icon.dart';

/// Acceso a la bandeja de chats (icono redondo, mismo patrón que notificaciones).
class MessagesIconButton extends StatelessWidget {
  const MessagesIconButton({
    super.key,
    required this.onPressed,
    this.unreadCount = 0,
    this.iconColor,
  });

  final VoidCallback onPressed;
  final int unreadCount;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final unread = unreadCount < 0 ? 0 : unreadCount;
    return HeaderIconButton(
      tooltip: unread > 0 ? 'Chats, $unread sin leer' : 'Chats',
      onPressed: onPressed,
      count: unread,
      badgeColor: AppColors.brand,
      iconColor: iconColor,
      icon: Icons.chat_bubble_outline,
      iconWidget: const LucideIcon(LucideGlyph.messageCircle, size: 22),
    );
  }
}
