import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/config/public_auth_route.dart';

void main() {
  test('detects /registro path and query fallback', () {
    expect(
      PublicAuthRoute.isRegister(
        Uri.parse('http://localhost:3000/registro'),
      ),
      isTrue,
    );
    expect(
      PublicAuthRoute.isRegister(
        Uri.parse('https://app.b2bconecta.com.ve/registro?utm_source=meta'),
      ),
      isTrue,
    );
    expect(
      PublicAuthRoute.isRegister(
        Uri.parse('http://localhost:3000/?registro=1'),
      ),
      isTrue,
    );
    expect(
      PublicAuthRoute.isRegister(
        Uri.parse('http://localhost:3000/#/registro'),
      ),
      isTrue,
    );
    expect(
      PublicAuthRoute.isRegister(
        Uri.parse('http://localhost:3000/registro/'),
      ),
      isTrue,
    );
  });

  test('shouldOpenRegister uses launch URI or route name', () {
    expect(
      PublicAuthRoute.shouldOpenRegister(
        launchUri: Uri.parse('http://localhost:3000/?registro=1'),
        routeName: '/',
      ),
      isTrue,
    );
    expect(
      PublicAuthRoute.shouldOpenRegister(routeName: '/registro'),
      isTrue,
    );
    expect(
      PublicAuthRoute.shouldOpenRegister(routeName: '/'),
      isFalse,
    );
  });

  test('does not treat home or legal as register', () {
    expect(
      PublicAuthRoute.isRegister(Uri.parse('http://localhost:3000/')),
      isFalse,
    );
    expect(
      PublicAuthRoute.isRegister(
        Uri.parse('https://www.b2bconecta.com.ve/?legal=terms'),
      ),
      isFalse,
    );
  });
}
