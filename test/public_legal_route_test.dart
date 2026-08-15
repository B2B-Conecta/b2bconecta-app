import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/config/public_legal_route.dart';

void main() {
  test('parses privacy and terms from query', () {
    expect(
      PublicLegalRoute.kindFromUri(
        Uri.parse('https://www.b2bconecta.com.ve/?legal=privacy'),
      ),
      PublicLegalKind.privacy,
    );
    expect(
      PublicLegalRoute.kindFromUri(
        Uri.parse('https://www.b2bconecta.com.ve/?legal=terms'),
      ),
      PublicLegalKind.terms,
    );
    expect(
      PublicLegalRoute.kindFromUri(
        Uri.parse('https://www.b2bconecta.com.ve/?legal=privacidad'),
      ),
      PublicLegalKind.privacy,
    );
  });

  test('ignores unrelated urls', () {
    expect(
      PublicLegalRoute.kindFromUri(
        Uri.parse('https://www.b2bconecta.com.ve/'),
      ),
      isNull,
    );
  });
}
