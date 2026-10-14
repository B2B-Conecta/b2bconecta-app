import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Acceso a la vista de chats. El encabezado muestra el nombre, no un icono de burbuja.
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
    return Tooltip(
      message: unread > 0 ? 'Chats, $unread sin leer' : 'Chats',
      child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Chats',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.brand,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
