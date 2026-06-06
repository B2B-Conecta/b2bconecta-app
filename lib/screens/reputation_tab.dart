import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/profile_model.dart';
import '../theme/app_theme.dart';
import '../widgets/aliado_reputation_panel.dart';
import '../widgets/importer_reputation_panel.dart';
import '../widgets/motolink_app_bar.dart';
import '../widgets/profile_section_helpers.dart';
import '../widgets/reputation_weekly_summary_section.dart';

/// E2: pantalla dedicada de reputación (desacoplada de pedidos y perfil operativo).
class ReputationTab extends StatelessWidget {
  const ReputationTab({
    super.key,
    required this.profile,
    required this.homeRole,
    required this.onNotificationTap,
    required this.unreadNotifications,
    required this.onProfileRefresh,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;
  final Future<void> Function() onProfileRefresh;

  @override
  Widget build(BuildContext context) {
    final isImportador = homeRole == AppHomeRole.importador;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MotolinkAppBar(
        currentUserProfile: profile,
        logoHeight: isImportador
            ? MotolinkAppBarLogoSizes.importador
            : MotolinkAppBarLogoSizes.aliado,
        onNotificationTap: onNotificationTap,
        unreadNotifications: unreadNotifications,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onProfileRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Text(
                        'Reputación',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    ProfileInfoIcon(
                      title: 'Reputación',
                      message: isImportador
                          ? 'Cierres semanales y valoraciones de aliados. '
                              'Es independiente del detalle de cada pedido.'
                          : 'Su reputación ante importadores: pagos, comunicación '
                              'y resumen semanal.',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const ReputationWeeklySummarySection(),
                const SizedBox(height: 16),
                if (isImportador)
                  ImporterReputationPanel(
                    profile: profile,
                    onProfileRefresh: onProfileRefresh,
                  )
                else
                  AliadoReputationPanel(
                    profile: profile,
                    onProfileRefresh: onProfileRefresh,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
