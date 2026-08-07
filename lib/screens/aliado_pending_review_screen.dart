import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_access_status.dart';
import '../models/in_app_notification_model.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/kyc_notification_match.dart';
import '../widgets/aliado_access_approved_banner.dart';
import '../widgets/motolink_pro_logo.dart';
import 'profile_setup_screen.dart';

/// Aliado con registro enviado o rechazado: sin acceso a MainShell hasta aprobación admin.
class AliadoPendingReviewScreen extends StatefulWidget {
  const AliadoPendingReviewScreen({
    super.key,
    required this.profile,
    required this.onRefresh,
  });

  final ProfileModel profile;
  final VoidCallback onRefresh;

  @override
  State<AliadoPendingReviewScreen> createState() =>
      _AliadoPendingReviewScreenState();
}

class _AliadoPendingReviewScreenState extends State<AliadoPendingReviewScreen> {
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _profileChannel;
  bool _approvedBannerVisible = false;
  String _approvedMessage =
      'Su acceso a B2B Conecta está habilitado. Ya puede operar en la plataforma.';

  bool get _isRejected =>
      widget.profile.accountAccessStatus?.trim() ==
      AccountAccessStatus.rejected;

  @override
  void initState() {
    super.initState();
    if (!_isRejected) {
      unawaited(PushNotificationService.instance.registerForCurrentUser());
      _notificationsChannel = SupabaseService.subscribeToMyNotifications(
        onInsert: _onNotificationInsert,
      );
      _profileChannel = SupabaseService.subscribeToMyProfileAccess(
        onAccessActive: _onAccessActive,
      );
    }
  }

  @override
  void dispose() {
    unawaited(SupabaseService.unsubscribeChannel(_notificationsChannel));
    unawaited(SupabaseService.unsubscribeChannel(_profileChannel));
    super.dispose();
  }

  void _onAccessActive() {
    if (!mounted || _isRejected) return;
    widget.onRefresh();
  }

  Future<void> _onNotificationInsert(InAppNotificationModel notification) async {
    if (!isAliadoAccessApprovedNotification(
      type: notification.type,
      title: notification.title,
    )) {
      return;
    }

    final body = notification.body.trim().isNotEmpty
        ? notification.body.trim()
        : _approvedMessage;

    await PushNotificationService.instance.showLocalBanner(
      title: notification.title.trim().isNotEmpty
          ? notification.title.trim()
          : 'Acceso validado',
      body: body,
      type: notification.type,
      relatedId: notification.relatedId,
      notificationId: notification.id,
    );

    if (!mounted) return;
    setState(() {
      _approvedBannerVisible = true;
      _approvedMessage = body;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_approvedBannerVisible)
              AliadoAccessApprovedBanner(
                message: _approvedMessage,
                onDismiss: () => setState(() => _approvedBannerVisible = false),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: MotoLinkProLogo(height: 56)),
                    const SizedBox(height: 28),
                    Text(
                      _isRejected
                          ? 'Solicitud no aprobada'
                          : 'Solicitud en revisión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRejected
                          ? 'B2B Conecta no pudo aprobar su registro inicial en este momento. '
                              'Revise el motivo, corrija la documentación y vuelva a enviar.'
                          : 'Recibimos su registro inicial. Un administrador de B2B Conecta '
                              'revisará su documentación y habilitará el acceso a la plataforma.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (_isRejected &&
                        widget.profile.accountReviewNote != null &&
                        widget.profile.accountReviewNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Motivo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.profile.accountReviewNote!.trim(),
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Estado: ${AccountAccessStatus.labelEs(widget.profile.accountAccessStatus)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!_isRejected) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Le avisaremos con una notificación push cuando su acceso sea validado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (_isRejected)
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProfileSetupScreen(
                                initial: widget.profile,
                                onProfileComplete: () {
                                  Navigator.of(context).pop();
                                  widget.onRefresh();
                                },
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Corregir y reenviar registro'),
                      ),
                    if (!_isRejected)
                      OutlinedButton(
                        onPressed: widget.onRefresh,
                        child: const Text('Actualizar estado'),
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        await AuthService.signOut();
                      },
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
