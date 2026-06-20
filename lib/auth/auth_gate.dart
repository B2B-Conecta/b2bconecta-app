import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/login_screen.dart';
import '../screens/recover_password_screen.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'auth_link_utils.dart';
import 'auth_recovery_storage.dart';
import 'auth_uri_callback_clear_stub.dart'
    if (dart.library.html) 'auth_uri_callback_clear_web.dart';
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

  /// Tras recovery sigue activo hasta [signedOut] o cambio de contraseña.
  bool _awaitingPasswordRecovery = false;

  /// Resolviendo `?code=` / fragmento Auth al abrir la app (web PKCE).
  bool _resolvingAuthCallback = false;

  /// Evita montar [ProfileGate] antes de resolver recovery vs login normal.
  bool _awaitingInitialAuthEvent = false;

  /// Mensaje de enlace inválido; no se limpia con setState para no recrear [LoginScreen].
  String? _initialLinkError;

  bool _bootstrapResolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );

    final uri = Uri.base;
    final link = parseAuthUriFragment(uri);
    _initialLinkError = link.errorMessage;
    _awaitingPasswordRecovery = link.isPasswordRecovery;

    if (_initialLinkError != null) {
      clearAuthUriCallback();
      unawaited(_signOutAfterLinkError());
      _bootstrapWithoutCallback();
    } else if (hasAuthCallbackInUri(uri)) {
      _resolvingAuthCallback = true;
      unawaited(_resolveAuthCallback(uri, link));
    } else {
      _bootstrapWithoutCallback();
    }
  }

  void _bootstrapWithoutCallback() {
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
    _bootstrapResolved = ! _awaitingInitialAuthEvent;
  }

  Future<void> _resolveAuthCallback(Uri uri, AuthLinkParseResult link) async {
    try {
      // Deja que Supabase.initialize termine detectSessionInUri si aplica.
      await Future<void>.delayed(const Duration(milliseconds: 80));

      var session = Supabase.instance.client.auth.currentSession;
      var redirectType = link.isPasswordRecovery ? 'recovery' : null;

      if (uri.queryParameters.containsKey('code')) {
        if (session == null) {
          try {
            final response =
                await Supabase.instance.client.auth.getSessionFromUrl(uri);
            session = response.session;
            redirectType = response.redirectType ?? redirectType;
          } on AuthException catch (e) {
            _initialLinkError = AuthService.mapAuthErrorMessage(e.message);
            await _signOutAfterLinkError();
            return;
          }
        }
      }

      clearAuthUriCallback();

      final pendingRecovery = redirectType == 'recovery' ||
          _awaitingPasswordRecovery ||
          await AuthRecoveryStorage.consumePendingPasswordRecovery();

      if (pendingRecovery && session != null) {
        _awaitingPasswordRecovery = true;
      } else if (session != null) {
        await AuthRecoveryStorage.clearPendingPasswordRecovery();
      }

      if (!mounted) return;
      setState(() {
        _authState = AuthState(
          session != null
              ? (pendingRecovery
                  ? AuthChangeEvent.passwordRecovery
                  : AuthChangeEvent.signedIn)
              : AuthChangeEvent.signedOut,
          session,
        );
      });
    } catch (e) {
      _initialLinkError ??=
          'No se pudo completar la autenticación desde el enlace.';
      await _signOutAfterLinkError();
    } finally {
      if (mounted) {
        setState(() {
          _resolvingAuthCallback = false;
          _awaitingInitialAuthEvent = false;
          _bootstrapResolved = true;
        });
      }
    }
  }

  Future<void> _signOutAfterLinkError() async {
    await AuthRecoveryStorage.clearPendingPasswordRecovery();
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
      unawaited(AuthRecoveryStorage.clearPendingPasswordRecovery());
      if (!_resolvingAuthCallback) {
        _applyAuthState(data);
      }
      return;
    }

    if (_resolvingAuthCallback && !_bootstrapResolved) {
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
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _bootstrapResolved) return;
        final pending = await AuthRecoveryStorage.consumePendingPasswordRecovery();
        if (pending || parseAuthUriFragment(Uri.base).isPasswordRecovery) {
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

  Future<void> _refreshSessionIfLoggedIn() async {
    final token =
        Supabase.instance.client.auth.currentSession?.refreshToken;
    if (token == null || token.isEmpty) return;
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_authState == null ||
        _resolvingAuthCallback ||
        _awaitingInitialAuthEvent) {
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
