import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

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
    final label = unread > 0 ? 'Mensajes ($unread sin leer)' : 'Mensajes';
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.brand,
        label: Text(
          unread > 9 ? '9+' : '$unread',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        child: Icon(
          unread > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
          color: unread > 0 ? AppColors.brand : AppColors.textSecondary,
        ),
      ),
    );
  }
}
