import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/notifications/web_push_service.dart';
import 'package:motolink_pro_app/core/notifications/web_push_status.dart';

/// Ajustes de Web Push (solo PWA / navegador).
class WebPushSettingsCard extends StatelessWidget {
  const WebPushSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final service = WebPushService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
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
                Text(
                  'Notificaciones en este dispositivo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _copy(service.status),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (service.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    service.lastError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (service.status.canActivate)
                      FilledButton(
                        onPressed: () => service.enableFromUserGesture(),
                        child: const Text('Activar notificaciones'),
                      ),
                    if (service.status == WebPushUiStatus.subscribed) ...[
                      OutlinedButton(
                        onPressed: () => service.disableFromUserGesture(),
                        child: const Text('Desactivar'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          try {
                            await service.sendTestNotification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enviamos una prueba a este dispositivo.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('No se pudo enviar la prueba: $e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Enviar prueba'),
                      ),
                    ],
                    if (service.status == WebPushUiStatus.error)
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

  static String _copy(WebPushUiStatus status) {
    switch (status) {
      case WebPushUiStatus.unsupported:
        return 'Este navegador no admite notificaciones Web Push.';
      case WebPushUiStatus.iosNeedsInstall:
        return 'En iPhone o iPad, toque Compartir y luego “Añadir a pantalla de inicio”. Abra B2B Conecta desde el icono y vuelva aquí para activar las notificaciones.';
      case WebPushUiStatus.permissionDefault:
        return 'Las notificaciones están apagadas. Solo se piden cuando usted toca Activar.';
      case WebPushUiStatus.permissionDenied:
        return 'El permiso está bloqueado en el navegador. En Ajustes → Safari (o Ajustes → B2B Conecta) permita las notificaciones y vuelva a intentar.';
      case WebPushUiStatus.subscribed:
        return 'Las notificaciones de este dispositivo están activas, incluso si deja la app en segundo plano.';
      case WebPushUiStatus.expired:
        return 'La suscripción venció o el navegador la renovó. Actívelas de nuevo.';
      case WebPushUiStatus.error:
        return 'No se pudo completar la suscripción. Revise la conexión e inténtelo otra vez.';
    }
  }
}
