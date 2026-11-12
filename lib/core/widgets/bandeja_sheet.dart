import 'package:flutter/material.dart';

import 'lucide_icon.dart';

/// Bottom sheet compartido: Mensajes + Notificaciones (Inicio / Catálogo / AppBar).
Future<void> showBandejaSheet({
  required BuildContext context,
  VoidCallback? onMessagesTap,
  VoidCallback? onNotificationTap,
  int unreadMessages = 0,
  int unreadNotifications = 0,
}) async {
  if (onMessagesTap == null && onNotificationTap == null) return;
  final action = await showModalBottomSheet<VoidCallback>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bandeja', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (onMessagesTap != null)
                ListTile(
                  onTap: () => Navigator.pop(sheet, onMessagesTap),
                  leading: const LucideIcon(LucideGlyph.messageCircle),
                  title: const Text('Mensajes'),
                  subtitle: unreadMessages > 0
                      ? Text('$unreadMessages sin leer')
                      : null,
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              if (onNotificationTap != null)
                ListTile(
                  onTap: () => Navigator.pop(sheet, onNotificationTap),
                  leading: const LucideIcon(LucideGlyph.bell),
                  title: const Text('Notificaciones'),
                  subtitle: unreadNotifications > 0
                      ? Text('$unreadNotifications sin leer')
                      : null,
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  action?.call();
}
