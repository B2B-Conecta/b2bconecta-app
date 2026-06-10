import 'package:flutter/material.dart';

import '../models/account_access_status.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/motolink_pro_logo.dart';
import 'profile_setup_screen.dart';

/// Aliado con registro enviado o rechazado: sin acceso a MainShell hasta aprobación admin.
class AliadoPendingReviewScreen extends StatelessWidget {
  const AliadoPendingReviewScreen({
    super.key,
    required this.profile,
    required this.onRefresh,
  });

  final ProfileModel profile;
  final VoidCallback onRefresh;

  bool get _isRejected =>
      profile.accountAccessStatus?.trim() == AccountAccessStatus.rejected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: MotoLinkProLogo(height: 56)),
              const SizedBox(height: 24),
              Icon(
                _isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
                size: 56,
                color: _isRejected ? Colors.red.shade700 : AppColors.brand,
              ),
              const SizedBox(height: 16),
              Text(
                _isRejected
                    ? 'Solicitud no aprobada'
                    : 'Solicitud en revisión',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRejected
                    ? 'MotoLink no pudo aprobar su registro inicial en este momento. '
                        'Revise el motivo, corrija la documentación y vuelva a enviar.'
                    : 'Recibimos su registro inicial. Un administrador de MotoLink '
                        'revisará su documentación y habilitará el acceso a la plataforma.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
              if (_isRejected &&
                  profile.accountReviewNote != null &&
                  profile.accountReviewNote!.trim().isNotEmpty) ...[
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
                          profile.accountReviewNote!.trim(),
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Estado: ${AccountAccessStatus.labelEs(profile.accountAccessStatus)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 28),
              if (_isRejected)
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileSetupScreen(
                          initial: profile,
                          onProfileComplete: () {
                            Navigator.of(context).pop();
                            onRefresh();
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
                  onPressed: onRefresh,
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
    );
  }
}
