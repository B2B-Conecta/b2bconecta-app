import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/login_screen.dart';
import '../screens/recover_password_screen.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'auth_link_fragment_clear_stub.dart'
    if (dart.library.html) 'auth_link_fragment_clear_web.dart';
import 'auth_link_utils.dart';
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

  /// Tras [AuthChangeEvent.passwordRecovery] sigue activo hasta [signedOut].
  bool _awaitingPasswordRecovery = false;

  /// Evita montar [ProfileGate] antes de resolver recovery vs login normal (web/PKCE).
  bool _awaitingInitialAuthEvent = false;

  /// Mensaje de enlace inválido; no se limpia con setState para no recrear [LoginScreen].
  String? _initialLinkError;

  /// Evita aplicar un [signedIn] diferido si ya llegó [passwordRecovery].
  bool _bootstrapResolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final link = parseAuthUriFragment(Uri.base);
    _awaitingPasswordRecovery = link.isPasswordRecovery;
    _initialLinkError = link.errorMessage;

    if (_initialLinkError != null) {
      clearAuthUriFragment();
      unawaited(_signOutAfterLinkError());
    }

    final bootSession = Supabase.instance.client.auth.currentSession;
    final hasLinkError = _initialLinkError != null;

    _awaitingInitialAuthEvent = bootSession != null &&
        !_awaitingPasswordRecovery &&
        !hasLinkError;

    _authState = AuthState(
      bootSession != null && !hasLinkError
          ? AuthChangeEvent.initialSession
          : AuthChangeEvent.signedOut,
      hasLinkError ? null : bootSession,
    );

    if (!hasLinkError && (link.isPasswordRecovery || bootSession != null)) {
      clearAuthUriFragment();
    }

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );
  }

  Future<void> _signOutAfterLinkError() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // La UI ya fuerza pantalla de login sin sesión.
    }
  }

  void _onAuthStateChange(AuthState data) {
    if (data.event == AuthChangeEvent.passwordRecovery &&
        data.session != null) {
      _awaitingPasswordRecovery = true;
      _bootstrapResolved = true;
      _applyAuthState(data);
      return;
    }

    if (data.event == AuthChangeEvent.signedOut || data.session == null) {
      _awaitingPasswordRecovery = false;
      _bootstrapResolved = true;
      _applyAuthState(data);
      return;
    }

    if (_awaitingInitialAuthEvent &&
        data.session != null &&
        !_bootstrapResolved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _bootstrapResolved) return;
        if (parseAuthUriFragment(Uri.base).isPasswordRecovery) {
          _awaitingPasswordRecovery = true;
        }
        _bootstrapResolved = true;
        _applyAuthState(data);
      });
      return;
    }

    _applyAuthState(data);
  }

  void _applyAuthState(AuthState data) {
    final shouldLogLogin = data.session != null &&
        !_awaitingPasswordRecovery &&
        (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.initialSession);

    if (shouldLogLogin) {
      final source = data.event == AuthChangeEvent.initialSession
          ? 'session_restore'
          : 'password';
      unawaited(SupabaseService.logUserLoginEvent(source: source));
    }

    if (mounted) {
      setState(() {
        _authState = data;
        _awaitingInitialAuthEvent = false;
      });
    }
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
      return const _AuthLoadingScaffold();
    }

    if (_awaitingInitialAuthEvent) {
      return const _AuthLoadingScaffold();
    }

    final session =
        _authState!.session ?? Supabase.instance.client.auth.currentSession;

    if (session != null && _awaitingPasswordRecovery) {
      return const RecoverPasswordScreen(key: ValueKey('recover_password'));
    }

    if (session != null) {
      return const ProfileGate(key: ValueKey('profile_gate'));
    }

    return LoginScreen(
      key: const ValueKey('login'),
      initialErrorMessage: _initialLinkError,
    );
  }
}

class _AuthLoadingScaffold extends StatelessWidget {
  const _AuthLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      ),
    );
  }
}
