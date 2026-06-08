import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/login_screen.dart';
import '../screens/recover_password_screen.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'profile_gate.dart';

/// Enruta entre login, recuperación de contraseña y app según sesión y evento Auth.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late final StreamSubscription<AuthState> _authSub;
  AuthState? _authState;

  /// Tras [AuthChangeEvent.passwordRecovery] sigue activo hasta [signedOut] (p. ej. token refrescado).
  bool _awaitingPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery &&
          data.session != null) {
        _awaitingPasswordRecovery = true;
      }
      if (data.event == AuthChangeEvent.signedOut || data.session == null) {
        _awaitingPasswordRecovery = false;
      }
      if (data.session != null &&
          (data.event == AuthChangeEvent.signedIn ||
              data.event == AuthChangeEvent.initialSession)) {
        final source = data.event == AuthChangeEvent.initialSession
            ? 'session_restore'
            : 'password';
        unawaited(SupabaseService.logUserLoginEvent(source: source));
      }
      setState(() => _authState = data);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSub.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshSessionIfLoggedIn());
    }
  }

  /// Solo refresca si ya hay sesión con refresh token (evita [AuthSessionMissingException] en login/registro).
  Future<void> _refreshSessionIfLoggedIn() async {
    final token =
        Supabase.instance.client.auth.currentSession?.refreshToken;
    if (token == null || token.isEmpty) return;
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {
      // Token inválido o revocado; el siguiente evento de auth actualizará la UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authState == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      );
    }

    final session =
        _authState!.session ?? Supabase.instance.client.auth.currentSession;

    if (session != null && _awaitingPasswordRecovery) {
      return const RecoverPasswordScreen();
    }

    if (session != null) {
      return const ProfileGate();
    }

    return const LoginScreen();
  }
}
