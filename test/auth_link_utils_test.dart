import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/auth/auth_link_utils.dart';

void main() {
  test('detects password recovery fragment', () {
    final uri = Uri.parse(
      'http://localhost:3000/#access_token=x&refresh_token=y&type=recovery',
    );
    final result = parseAuthUriFragment(uri);
    expect(result.isPasswordRecovery, isTrue);
    expect(result.errorMessage, isNull);
  });

  test('detects PKCE auth callback with code query param', () {
    final uri = Uri.parse(
      'https://motolink-app.vercel.app/?code=abc-123',
    );
    expect(hasAuthCallbackInUri(uri), isTrue);
    expect(parseAuthUriFragment(uri).isPasswordRecovery, isFalse);
  });

  test('maps expired otp error from fragment', () {
    final uri = Uri.parse(
      'http://localhost:3000/#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired',
    );
    final result = parseAuthUriFragment(uri);
    expect(result.isPasswordRecovery, isFalse);
    expect(
      result.errorMessage,
      'El enlace del correo expiró o ya fue usado. Solicita uno nuevo.',
    );
  });
}
