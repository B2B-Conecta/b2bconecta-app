import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../screens/home_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../services/supabase_service.dart';

const _kCorporateRed = Color(0xFFE31B23);

/// Tras login: carga `profiles` y muestra onboarding o [HomeScreen].
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
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _kCorporateRed),
                  SizedBox(height: 16),
                  Text(
                    'Cargando perfil...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
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
        final needsSetup = profile == null || !profile.isComplete;

        if (needsSetup) {
          return ProfileSetupScreen(
            initial: profile,
            onProfileComplete: _reloadProfile,
          );
        }

        return const HomeScreen();
      },
    );
  }
}
