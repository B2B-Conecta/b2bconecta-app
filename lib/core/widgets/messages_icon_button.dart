import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'header_icon_button.dart';

/// Acceso persistente a la bandeja de mensajes de pedido.
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
      tooltip: unread > 0 ? 'Mensajes ($unread sin leer)' : 'Mensajes',
      onPressed: onPressed,
      count: unread,
      icon: unread > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
      iconColor: unread > 0 ? AppColors.brand : AppColors.textSecondary,
    );
  }
}
