import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'aliado_pending_review_screen.dart';
import 'package:motolink_pro_app/app/main_shell.dart';
import 'profile_setup_screen.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

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

  AppHomeRole _homeRoleFor(ProfileModel profile) {
    switch (profile.role?.trim().toLowerCase()) {
      case 'aliado':
        return AppHomeRole.aliado;
      case 'administrador':
        return AppHomeRole.administrador;
      default:
        return AppHomeRole.importador;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileModel?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
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
                          TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 13),
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

        if (profile == null || !profile.hasValidAppRole || !profile.isComplete) {
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

        if ((profile.isAliado || profile.isImportador) &&
            !profile.hasActiveAccountAccess) {
          if (profile.needsPendingReviewScreen) {
            return AliadoPendingReviewScreen(
              profile: profile,
              onRefresh: _reloadProfile,
            );
          }
          return ProfileSetupScreen(
            initial: profile,
            onProfileComplete: _reloadProfile,
          );
        }

        if (profile.isReadyForMainApp) {
          return MainShell(homeRole: _homeRoleFor(profile), profile: profile);
        }

        return ProfileSetupScreen(
          initial: profile,
          onProfileComplete: _reloadProfile,
        );
      },
    );
  }
}
