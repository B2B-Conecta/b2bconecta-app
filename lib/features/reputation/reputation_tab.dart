import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'reputation_overview.dart';
import 'package:motolink_pro_app/core/widgets/motolink_app_bar.dart';

/// E2: pantalla dedicada de reputación (desacoplada de pedidos y perfil operativo).
class ReputationTab extends StatelessWidget {
  const ReputationTab({
    super.key,
    required this.profile,
    required this.homeRole,
    required this.onNotificationTap,
    required this.unreadNotifications,
    this.onMessagesTap,
    this.unreadMessages = 0,
    required this.onProfileRefresh,
    this.embedInDesktopShell = false,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
  final Future<void> Function() onProfileRefresh;
  final bool embedInDesktopShell;

  @override
  Widget build(BuildContext context) {
    final isImportador = homeRole == AppHomeRole.importador;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: embedInDesktopShell
          ? null
          : MotolinkAppBar(
              currentUserProfile: profile,
              logoHeight: isImportador
                  ? MotolinkAppBarLogoSizes.importador
                  : MotolinkAppBarLogoSizes.aliado,
              onNotificationTap: onNotificationTap,
              unreadNotifications: unreadNotifications,
              onMessagesTap: onMessagesTap,
              unreadMessages: unreadMessages,
            ),
      body: SafeArea(
        child: ReputationOverview(
          profile: profile,
          isImporter: isImportador,
          showHeading: !embedInDesktopShell,
          onProfileRefresh: onProfileRefresh,
        ),
      ),
    );
  }
}
