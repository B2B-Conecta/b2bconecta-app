import 'package:flutter/material.dart';

import '../models/account_access_status.dart';
import '../models/app_home_role.dart';
import '../models/profile_model.dart';
import '../screens/aliado_pending_review_screen.dart';
import '../screens/main_shell.dart';
import '../screens/profile_setup_screen.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Tras login: carga `profiles` y muestra onboarding o [MainShell].
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<ProfileModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = SupabaseService.fetchMyProfile();
  }

  void _reloadProfile() {
    setState(() {
      _profileFuture = SupabaseService.fetchMyProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileModel?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.brand),
                  SizedBox(height: 16),
                  Text(
                    'Cargando perfil...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade700),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudo cargar el perfil.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade800, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _reloadProfile,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data;
        final roleNorm = profile?.role?.trim().toLowerCase();
        final hasValidRole = roleNorm == 'importador' ||
            roleNorm == 'aliado' ||
            roleNorm == 'administrador';
        final needsOnboarding =
            profile == null || !hasValidRole || !profile.isComplete;

        if (needsOnboarding) {
          return ProfileSetupScreen(
            initial: profile,
            onProfileComplete: _reloadProfile,
          );
        }

        if (profile.requiresTermsAcceptance && !profile.hasAcceptedCurrentTerms) {
          return ProfileSetupScreen(
            initial: profile,
            onProfileComplete: _reloadProfile,
          );
        }

        if (profile.isAliado && !profile.hasActiveAccountAccess) {
          final access = profile.accountAccessStatus?.trim();
          if (access == AccountAccessStatus.draft ||
              access == null ||
              access.isEmpty) {
            return ProfileSetupScreen(
              initial: profile,
              onProfileComplete: _reloadProfile,
            );
          }
          return AliadoPendingReviewScreen(
            profile: profile,
            onRefresh: _reloadProfile,
          );
        }

        final AppHomeRole homeRole;
        switch (roleNorm) {
          case 'aliado':
            homeRole = AppHomeRole.aliado;
            break;
          case 'administrador':
            homeRole = AppHomeRole.administrador;
            break;
          default:
            homeRole = AppHomeRole.importador;
        }
        return MainShell(homeRole: homeRole, profile: profile);
      },
    );
  }
}
