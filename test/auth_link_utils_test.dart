import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/auth/auth_link_utils.dart';
import 'package:motolink_pro_app/core/auth/auth_service.dart';

void main() {
  test('detects password recovery fragment', () {
    final uri = Uri.parse(
      'http://localhost:3000/#access_token=x&refresh_token=y&type=recovery',
    );
    final result = parseAuthUriFragment(uri);
    expect(result.isPasswordRecovery, isTrue);
    expect(result.isSignupConfirmation, isFalse);
    expect(result.errorMessage, isNull);
  });

  test('detects signup confirmation fragment', () {
    final uri = Uri.parse(
      'http://localhost:3000/#access_token=x&type=signup',
    );
    final result = parseAuthUriFragment(uri);
    expect(result.isSignupConfirmation, isTrue);
    expect(result.isPasswordRecovery, isFalse);
  });

  test('detects PKCE auth callback with code query param', () {
    final uri = Uri.parse(
      'https://b2bconecta-app-git-dev-b2bconecta.vercel.app/?code=abc-123',
    );
    expect(hasAuthCallbackInUri(uri), isTrue);
    expect(parseAuthUriFragment(uri).isPasswordRecovery, isFalse);
  });

  test('detects Android custom scheme PKCE callback', () {
    final uri = Uri.parse(
      've.com.b2bconecta.app://auth-callback?code=abc-123',
    );
    expect(hasAuthCallbackInUri(uri), isTrue);
    expect(uri.host, 'auth-callback');
  });

  test('detects password recovery from query type param', () {
    final uri = Uri.parse(
      'https://www.b2bconecta.com.ve/?code=abc&type=recovery',
    );
    final result = parseAuthUriFragment(uri);
    expect(result.isPasswordRecovery, isTrue);
    expect(hasAuthCallbackInUri(uri), isTrue);
  });

  test('shouldForcePasswordRecoveryScreen when pending flag set', () {
    expect(
      shouldForcePasswordRecoveryScreen(
        awaitingPasswordRecovery: false,
        pendingPasswordRecovery: true,
      ),
      isTrue,
    );
    expect(
      shouldForcePasswordRecoveryScreen(
        awaitingPasswordRecovery: true,
        pendingPasswordRecovery: false,
      ),
      isTrue,
    );
  });

  test('maps expired otp error from fragment for signup', () {
    final uri = Uri.parse(
      'http://localhost:3000/#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired&type=signup',
    );
    final result = parseAuthUriFragment(uri);
    expect(result.isSignupConfirmation, isTrue);
    expect(
      result.errorMessage,
      contains('confirmación'),
    );
  });

  test('code verifier message is signup-aware', () {
    final signup = AuthService.mapAuthErrorMessage(
      'Code verifier could not be found',
      kind: AuthCallbackKind.signup,
    );
    expect(signup.toLowerCase(), contains('confirmación'));
    expect(signup.toLowerCase(), isNot(contains('recuperación')));

    final recovery = AuthService.mapAuthErrorMessage(
      'Code verifier could not be found',
      kind: AuthCallbackKind.recovery,
    );
    expect(recovery.toLowerCase(), contains('recuperación'));
  });
}
