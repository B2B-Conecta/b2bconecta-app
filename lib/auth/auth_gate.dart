import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_scaffold_messenger.dart';
import '../screens/login_screen.dart';
import '../screens/recover_password_screen.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'auth_incoming_uri.dart';
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
  static const _authCallbackTimeout = Duration(seconds: 10);

  late final StreamSubscription<AuthState> _authSub;
  StreamSubscription<Uri>? _deepLinkSub;
  AuthState? _authState;

  /// Tras recovery sigue activo hasta [signedOut] o cambio de contraseña.
  bool _awaitingPasswordRecovery = false;

  /// Resolviendo `?code=` / fragmento Auth al abrir la app (PKCE / implicit).
  bool _resolvingAuthCallback = false;

  /// Espera breve solo cuando hay deep link Auth pendiente (no en arranque normal).
  bool _awaitingInitialAuthEvent = false;

  /// Bootstrap async (móvil: leer intent antes de enrutar).
  bool _bootstrapping = true;

  /// Mensaje de enlace inválido; no se limpia con setState para no recrear [LoginScreen].
  String? _initialLinkError;

  bool _bootstrapResolved = false;

  Timer? _authCallbackTimeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );

    if (!kIsWeb) {
      _deepLinkSub = AppLinks().uriLinkStream.listen(_onIncomingDeepLink);
    }

    unawaited(_bootstrapAuth());
  }

  Future<void> _bootstrapAuth() async {
    final incomingUri = await resolveIncomingAuthCallbackUri();
    final uri = incomingUri ?? Uri.base;
    final link = parseAuthUriFragment(uri);
    final pendingRecoveryRequest =
        await AuthRecoveryStorage.peekPendingPasswordRecovery();
    final hasIncomingCallback = hasAuthCallbackInUri(uri);

    _initialLinkError = link.errorMessage;
    _awaitingPasswordRecovery =
        link.isPasswordRecovery || pendingRecoveryRequest;

    if (_initialLinkError != null) {
      clearAuthUriCallback();
      await _signOutAfterLinkError();
      _bootstrapWithoutCallback(expectAuthCallback: false);
    } else if (hasIncomingCallback) {
      _resolvingAuthCallback = true;
      _startAuthCallbackTimeout();
      await _resolveAuthCallback(uri, link);
    } else if (pendingRecoveryRequest &&
        Supabase.instance.client.auth.currentSession != null) {
      _awaitingPasswordRecovery = true;
      _bootstrapWithoutCallback(expectAuthCallback: false);
    } else if (pendingRecoveryRequest) {
      // Usuario pidió reset; Supabase puede estar procesando el intent en paralelo.
      _awaitingInitialAuthEvent = true;
      _bootstrapResolved = false;
      _startAuthCallbackTimeout(onTimeout: () async {
        final pending =
            await AuthRecoveryStorage.consumePendingPasswordRecovery();
        if (pending && mounted) {
          setState(() {
            _initialLinkError ??=
                'No se recibió el enlace de recuperación. Abre el correo de nuevo o solicita uno nuevo.';
            _awaitingInitialAuthEvent = false;
            _bootstrapResolved = true;
          });
        }
      });
      _bootstrapWithoutCallback(expectAuthCallback: false);
    } else {
      _bootstrapWithoutCallback(expectAuthCallback: false);
    }

    if (mounted) {
      setState(() => _bootstrapping = false);
    }
  }

  void _startAuthCallbackTimeout({Future<void> Function()? onTimeout}) {
    _authCallbackTimeoutTimer?.cancel();
    _authCallbackTimeoutTimer = Timer(_authCallbackTimeout, () async {
      if (!mounted || _bootstrapResolved) return;
      await onTimeout?.call();
      if (!mounted || _bootstrapResolved) return;
      setState(() {
        _resolvingAuthCallback = false;
        _awaitingInitialAuthEvent = false;
        _bootstrapResolved = true;
        _initialLinkError ??=
            'El enlace tardó demasiado en abrirse. Intenta de nuevo desde el correo.';
      });
    });
  }

  void _clearAuthCallbackTimeout() {
    _authCallbackTimeoutTimer?.cancel();
    _authCallbackTimeoutTimer = null;
  }

  void _onIncomingDeepLink(Uri uri) {
    if (!hasAuthCallbackInUri(uri)) return;

    final link = parseAuthUriFragment(uri);
    if (link.errorMessage != null) {
      _initialLinkError = link.errorMessage;
      unawaited(_signOutAfterLinkError());
      if (mounted) {
        setState(() {
          _bootstrapResolved = true;
          _awaitingInitialAuthEvent = false;
          _resolvingAuthCallback = false;
        });
      }
      return;
    }

    if (link.isPasswordRecovery) {
      _awaitingPasswordRecovery = true;
    }

    if (!_resolvingAuthCallback) {
      _resolvingAuthCallback = true;
      unawaited(_resolveAuthCallback(uri, link));
    }
  }

  void _bootstrapWithoutCallback({required bool expectAuthCallback}) {
    final bootSession = Supabase.instance.client.auth.currentSession;
    final hasLinkError = _initialLinkError != null;

    // Solo bloquear si hay callback Auth activo; sesión persistida ≠ deep link pendiente.
    _awaitingInitialAuthEvent = expectAuthCallback &&
        bootSession != null &&
        !_awaitingPasswordRecovery &&
        !hasLinkError;

    _authState = AuthState(
      bootSession != null && !hasLinkError
          ? AuthChangeEvent.initialSession
          : AuthChangeEvent.signedOut,
      hasLinkError ? null : bootSession,
    );
    if (!_awaitingInitialAuthEvent) {
      _bootstrapResolved = true;
    }
  }

  Future<void> _resolveAuthCallback(Uri uri, AuthLinkParseResult link) async {
    try {
      // Deja que Supabase.initialize termine detectSessionInUri si aplica.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      var session = Supabase.instance.client.auth.currentSession;
      var redirectType = link.isPasswordRecovery ? 'recovery' : null;

      if (uri.queryParameters.containsKey('code')) {
        try {
          final response =
              await Supabase.instance.client.auth.getSessionFromUrl(uri);
          session = response.session;
          redirectType = response.redirectType ?? redirectType;
        } on AuthException catch (e) {
          if (session == null) {
            _initialLinkError = AuthService.mapAuthErrorMessage(e.message);
            await _signOutAfterLinkError();
            return;
          }
          redirectType ??=
              (await AuthRecoveryStorage.peekPendingPasswordRecovery())
                  ? 'recovery'
                  : null;
        }
      } else if (session != null) {
        redirectType ??=
            (await AuthRecoveryStorage.peekPendingPasswordRecovery())
                ? 'recovery'
                : null;
      }

      clearAuthUriCallback();

      final pendingRecovery = redirectType == 'recovery' ||
          _awaitingPasswordRecovery ||
          await AuthRecoveryStorage.peekPendingPasswordRecovery();

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
      _clearAuthCallbackTimeout();
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
      _clearAuthCallbackTimeout();
      unawaited(AuthRecoveryStorage.clearPendingPasswordRecovery());
      _applyAuthState(data);
      return;
    }

    if (_resolvingAuthCallback && !_bootstrapResolved) {
      return;
    }

    if (data.event == AuthChangeEvent.signedOut || data.session == null) {
      _awaitingPasswordRecovery = false;
      _bootstrapResolved = true;
      _clearAuthCallbackTimeout();
      _applyAuthState(data);
      // Cerrar ajustes/perfil apilados para mostrar login de inmediato.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        popNavigationToRoot();
      });
      return;
    }

    if (_awaitingInitialAuthEvent &&
        data.session != null &&
        !_bootstrapResolved) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _bootstrapResolved) return;
        final pending =
            await AuthRecoveryStorage.peekPendingPasswordRecovery();
        if (pending) {
          _awaitingPasswordRecovery = true;
        }
        _bootstrapResolved = true;
        _clearAuthCallbackTimeout();
        _applyAuthState(data);
      });
      return;
    }

    if (data.session != null &&
        !_awaitingPasswordRecovery &&
        (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.initialSession)) {
      unawaited(_applyAuthStateMaybeRecovery(data));
      return;
    }

    _applyAuthState(data);
  }

  Future<void> _applyAuthStateMaybeRecovery(AuthState data) async {
    if (!_awaitingPasswordRecovery &&
        await AuthRecoveryStorage.peekPendingPasswordRecovery()) {
      _awaitingPasswordRecovery = true;
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
    _clearAuthCallbackTimeout();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSub.cancel());
    unawaited(_deepLinkSub?.cancel());
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
    if (_bootstrapping ||
        _authState == null ||
        _resolvingAuthCallback ||
        _awaitingInitialAuthEvent) {
      return const _AuthLoadingScaffold();
    }

    final session =
        _authState!.session ?? Supabase.instance.client.auth.currentSession;

    if (session != null &&
        shouldForcePasswordRecoveryScreen(
          awaitingPasswordRecovery: _awaitingPasswordRecovery,
          pendingPasswordRecovery: false,
        )) {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      ),
    );
  }
}
