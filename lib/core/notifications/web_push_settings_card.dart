import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/notifications/web_push_service.dart';
import 'package:motolink_pro_app/core/notifications/web_push_status.dart';

/// Ajustes de avisos en la PWA / panel web (solo web).
class WebPushSettingsCard extends StatelessWidget {
  const WebPushSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final service = WebPushService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final status = service.status;
        final desktop = service.isDesktopWeb;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppDecorations.radius12,
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: AppDecorations.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.brandBlueContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        status.isActive
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_none_outlined,
                        color: AppColors.brandBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            desktop
                                ? 'Notificaciones en esta Mac/PC'
                                : 'Avisos en este dispositivo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _StatusPill(status: status),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _copy(status, desktop: desktop),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (service.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    service.lastError!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (status.canActivate)
                      FilledButton(
                        onPressed: () => service.enableFromUserGesture(),
                        child: Text(
                          desktop
                              ? 'Activar notificaciones en esta Mac/PC'
                              : 'Activar avisos',
                        ),
                      ),
                    if (status == WebPushUiStatus.subscribed) ...[
                      OutlinedButton(
                        onPressed: () => service.disableFromUserGesture(),
                        child: const Text('Pausar'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            await service.sendTestNotification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    desktop
                                        ? 'Te enviamos un aviso de prueba. Minimiza o cambia de pestaña para verlo en el Centro de Notificaciones.'
                                        : 'Te enviamos un aviso de prueba. Bloquea el iPhone para verlo fuera de la app.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No pudimos enviar el aviso de prueba. Inténtalo de nuevo.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Probar aviso'),
                      ),
                    ],
                    if (status == WebPushUiStatus.error)
                      OutlinedButton(
                        onPressed: () => service.enableFromUserGesture(),
                        child: const Text('Reintentar'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _copy(WebPushUiStatus status, {required bool desktop}) {
    switch (status) {
      case WebPushUiStatus.unsupported:
        return desktop
            ? 'Este navegador no admite notificaciones push. Usa Safari 16+ en macOS 13+, o Chrome/Edge actualizados.'
            : 'Este dispositivo no puede mostrar avisos de B2B Conecta. En iPhone usa Safari, añade la app a inicio y ábrela desde el icono.';
      case WebPushUiStatus.iosNeedsInstall:
        return 'En iPhone o iPad: toca Compartir y luego “Añadir a pantalla de inicio”. Abre B2B Conecta desde el icono y vuelve aquí para activar los avisos.';
      case WebPushUiStatus.permissionDefault:
        return desktop
            ? 'Recibe pedidos, inventario y mensajes en el Centro de Notificaciones del sistema aunque la pestaña esté en segundo plano. Solo pedimos permiso al pulsar el botón.'
            : 'Te avisamos de pedidos y mensajes aunque no tengas la app abierta. Solo pedimos permiso cuando toques Activar avisos.';
      case WebPushUiStatus.permissionDenied:
        return desktop
            ? 'Las notificaciones están bloqueadas. En Safari: Ajustes → Sitios web → Notificaciones. En Chrome/Edge: icono del candado en la barra de direcciones → Notificaciones → Permitir.'
            : 'Los avisos están bloqueados. En Ajustes del iPhone busca B2B Conecta y permite las notificaciones.';
      case WebPushUiStatus.subscribed:
        return desktop
            ? 'Listo. Las alertas aparecerán en el Centro de Notificaciones de tu Mac/PC cuando la pestaña esté minimizada o en segundo plano.'
            : 'Listo. Te llegarán pedidos y mensajes aunque dejes la app en segundo plano o bloquees el iPhone.';
      case WebPushUiStatus.expired:
        return desktop
            ? 'Hay que volver a activar las notificaciones en este equipo. Pulsa el botón para continuar.'
            : 'Hay que volver a activar los avisos en este dispositivo. Toca Activar avisos para continuar.';
      case WebPushUiStatus.error:
        return desktop
            ? 'No pudimos activar las notificaciones. Revisa la conexión e inténtalo de nuevo.'
            : 'No pudimos activar los avisos. Revisa la conexión e inténtalo de nuevo.';
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final WebPushUiStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      WebPushUiStatus.subscribed => 'Activos',
      WebPushUiStatus.permissionDenied ||
      WebPushUiStatus.error =>
        'Requieren atención',
      WebPushUiStatus.iosNeedsInstall => 'Falta el icono',
      WebPushUiStatus.unsupported => 'No disponibles',
      WebPushUiStatus.expired => 'Hay que renovar',
      WebPushUiStatus.permissionDefault => 'Apagados',
    };
    final active = status.isActive;
    final alert = status == WebPushUiStatus.permissionDenied ||
        status == WebPushUiStatus.error;
    final Color bg;
    final Color fg;
    if (active) {
      bg = AppColors.successGreen.withOpacity(0.12);
      fg = AppColors.successGreen;
    } else if (alert) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    } else {
      bg = AppColors.brandBlueContainer;
      fg = AppColors.brandBlue;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
