import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/notifications/web_push_service.dart';
import 'package:motolink_pro_app/core/notifications/web_push_status.dart';

/// Soft prompt for desktop web: enable OS notifications via an explicit gesture.
class WebPushEnableBanner extends StatefulWidget {
  const WebPushEnableBanner({super.key});

  static const prefsKey = 'web_push_desktop_prompt_dismissed_v1';

  @override
  State<WebPushEnableBanner> createState() => _WebPushEnableBannerState();
}

class _WebPushEnableBannerState extends State<WebPushEnableBanner> {
  bool _dismissed = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    WebPushService.instance.addListener(_onService);
    _loadDismissed();
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WebPushService.instance.removeListener(_onService);
    }
    super.dispose();
  }

  void _onService() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissed = prefs.getBool(WebPushEnableBanner.prefsKey) ?? false;
    } catch (_) {
      _dismissed = false;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(WebPushEnableBanner.prefsKey, true);
    } catch (_) {}
  }

  Future<void> _enable() async {
    await WebPushService.instance.enableFromUserGesture();
    if (WebPushService.instance.status == WebPushUiStatus.subscribed) {
      await _dismiss();
    }
  }

  bool get _shouldShow {
    if (!kIsWeb || !_loaded || _dismissed) return false;
    final service = WebPushService.instance;
    if (!service.isDesktopWeb) return false;
    final status = service.status;
    return status == WebPushUiStatus.permissionDefault ||
        status == WebPushUiStatus.expired;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();
    return Material(
      color: AppColors.brandBlueContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.brandBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activar notificaciones en esta Mac/PC',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pedidos, inventario y mensajes en el Centro de Notificaciones, aunque la pestaña esté en segundo plano.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _enable,
                          child: const Text('Activar ahora'),
                        ),
                        TextButton(
                          onPressed: _dismiss,
                          child: const Text('Ahora no'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: _dismiss,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
