import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'header_icon_button.dart';

/// Acceso a la bandeja de chats (icono, mismo patrón que notificaciones).
class MessagesIconButton extends StatelessWidget {
  const MessagesIconButton({
    super.key,
    required this.onPressed,
    this.unreadCount = 0,
  });

  final VoidCallback onPressed;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final unread = unreadCount < 0 ? 0 : unreadCount;
    return HeaderIconButton(
      tooltip: unread > 0 ? 'Chats, $unread sin leer' : 'Chats',
      onPressed: onPressed,
      count: unread,
      badgeColor: AppColors.brand,
      icon: unread > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
    );
  }
}
