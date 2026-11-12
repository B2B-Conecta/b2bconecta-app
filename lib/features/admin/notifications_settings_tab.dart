import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/notifications/web_push_settings_card.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_notification_prefs.dart';

/// Preferencias de notificaciones del panel admin (Ajustes → Notificaciones).
class NotificationPreferencesTab extends StatefulWidget {
  const NotificationPreferencesTab({super.key});

  @override
  State<NotificationPreferencesTab> createState() =>
      _NotificationPreferencesTabState();
}

/// Alias histórico para el hub de ajustes.
typedef NotificationsSettingsTab = NotificationPreferencesTab;

class _NotificationPreferencesTabState
    extends State<NotificationPreferencesTab> {
  AdminNotificationPrefs? _prefs;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await AdminNotificationPrefs.load();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    setState(() => _saving = true);
    try {
      await p.save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferencias de notificación actualizadas'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);

    if (_loading || _prefs == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.brand,
          ),
        ),
      );
    }
    final p = _prefs!;
    final muted = p.muteAll;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: theme.textPrimary.withOpacity(
                        Theme.of(context).brightness == Brightness.dark
                            ? 0.35
                            : 0.04,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Notificaciones',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alertas del panel administrativo y correos automáticos en este dispositivo.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _MuteAllCard(
                      theme: theme,
                      value: p.muteAll,
                      onChanged: (v) => setState(() => p.muteAll = v),
                    ),
                    const SizedBox(height: 20),
                    AnimatedOpacity(
                      opacity: muted ? 0.5 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: IgnorePointer(
                        ignoring: muted,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionLabel(
                              theme: theme,
                              label: 'Actividad operativa y pedidos',
                            ),
                            _PrefSwitch(
                              theme: theme,
                              title: 'Alerta por cada nuevo pedido',
                              subtitle:
                                  'Recibe una notificación inmediata y sonido sutil cuando un taller confirme una compra.',
                              value: p.newOrderAlerts,
                              onChanged: (v) =>
                                  setState(() => p.newOrderAlerts = v),
                            ),
                            _PrefSwitch(
                              theme: theme,
                              title: 'Nuevos talleres y documentos pendientes',
                              subtitle:
                                  'Avisa cuando un minorista o mayorista suba su RIF, registro mercantil o fotos de tienda.',
                              value: p.kycPendingAlerts,
                              onChanged: (v) =>
                                  setState(() => p.kycPendingAlerts = v),
                            ),
                            _PrefSwitch(
                              theme: theme,
                              title: 'Avisos de nuevos mensajes en soporte',
                              subtitle:
                                  'Notificación instantánea en el navegador cuando un aliado abra un ticket de ayuda.',
                              value: p.supportMessageAlerts,
                              onChanged: (v) =>
                                  setState(() => p.supportMessageAlerts = v),
                            ),
                            _PrefSwitch(
                              theme: theme,
                              title:
                                  'Resumen semanal de operaciones (Digest)',
                              subtitle:
                                  'Envía cada lunes a tu correo el consolidado de ventas en USD, comisiones y talleres activos.',
                              value: p.weeklyDigest,
                              onChanged: (v) =>
                                  setState(() => p.weeklyDigest = v),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                height: 1,
                                color: theme.borderSubtle,
                              ),
                            ),
                            _SectionLabel(
                              theme: theme,
                              label: 'Sistema, tasas y novedades',
                            ),
                            _PrefSwitch(
                              theme: theme,
                              title: 'Alertas de actualización de tasa BCV',
                              subtitle:
                                  'Notifica automáticamente en el panel cada vez que se sincronice el tipo de cambio oficial.',
                              value: p.bcvRateAlerts,
                              onChanged: (v) =>
                                  setState(() => p.bcvRateAlerts = v),
                            ),
                            _PrefSwitch(
                              theme: theme,
                              title:
                                  'Actualizaciones del sistema y nuevas funciones',
                              subtitle:
                                  'Entérate de nuevas herramientas administrativas, reportes y mejoras de rendimiento en B2B Conecta.',
                              value: p.platformUpdates,
                              onChanged: (v) =>
                                  setState(() => p.platformUpdates = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: _saving ? null : _persist,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.brand,
                          foregroundColor: theme.surfaceCard,
                          disabledBackgroundColor:
                              theme.brand.withOpacity(0.55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _saving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: theme.surfaceCard,
                                ),
                              )
                            : const Text(
                                'Guardar preferencias',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Push en este navegador',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Permisos del navegador para avisos en tiempo real.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const WebPushSettingsCard(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MuteAllCard extends StatelessWidget {
  const _MuteAllCard({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  final B2BThemeExtension theme;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: LucideIcon(
              value ? LucideGlyph.bellOff : LucideGlyph.bellRing,
              size: 20,
              color: theme.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Silenciar todas las notificaciones',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pausa temporalmente todas las alertas del panel y correos automáticos mientras estás ausente.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: theme.brand,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.theme, required this.label});

  final B2BThemeExtension theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: theme.textSecondary,
        ),
      ),
    );
  }
}

class _PrefSwitch extends StatelessWidget {
  const _PrefSwitch({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final B2BThemeExtension theme;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        activeColor: theme.brand,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: theme.textSecondary,
          ),
        ),
      ),
    );
  }
}
