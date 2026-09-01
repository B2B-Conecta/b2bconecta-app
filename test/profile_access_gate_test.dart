import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/config/terms_config.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

ProfileModel _aliado({
  String access = AccountAccessStatus.draft,
  String? fiscalMapsUrl,
  String? estado = 'Miranda',
  String? ciudad = 'Caracas',
  String? direccion = 'Av. Principal, Local 1',
  DateTime? termsAcceptedAt,
  String? termsVersion,
}) {
  return ProfileModel(
    id: 'aliado-1',
    role: 'aliado',
    businessName: 'Pedro Aliado',
    rif: 'J-12345678-9',
    accountAccessStatus: access,
    fiscalMapsUrl: fiscalMapsUrl,
    estado: estado,
    ciudad: ciudad,
    direccion: direccion,
    termsAcceptedAt: termsAcceptedAt,
    termsVersion: termsVersion,
  );
}

void main() {
  group('aliado con acceso activo', () {
    test('entra a la app aunque falte Google Maps', () {
      final p = _aliado(
        access: AccountAccessStatus.active,
        fiscalMapsUrl: null,
        termsAcceptedAt: DateTime.utc(2026, 6, 13),
        termsVersion: TermsConfig.currentVersion,
      );

      expect(p.hasFiscalMapsShareLink, isFalse);
      expect(p.hasActiveAccountAccess, isTrue);
      expect(p.isReadyForMainApp, isTrue);
      expect(p.needsPendingReviewScreen, isFalse);
    });

    test('isComplete no exige Maps ni contacto legal si ya está activo', () {
      final p = _aliado(
        access: AccountAccessStatus.active,
        fiscalMapsUrl: null,
      );

      expect(p.isComplete, isTrue);
    });
  });

  group('aliado en registro inicial', () {
    test('sin Maps no está completo y no entra a la app', () {
      final p = _aliado(
        access: AccountAccessStatus.draft,
        fiscalMapsUrl: null,
        termsAcceptedAt: DateTime.utc(2026, 6, 13),
        termsVersion: TermsConfig.currentVersion,
      );

      expect(p.isComplete, isFalse);
      expect(p.isReadyForMainApp, isFalse);
      expect(p.needsPendingReviewScreen, isFalse);
    });

    test('con Maps y domicilio, el borrador sigue esperando aprobación', () {
      final p = _aliado(
        access: AccountAccessStatus.draft,
        fiscalMapsUrl: 'https://maps.app.goo.gl/abc',
        termsAcceptedAt: DateTime.utc(2026, 6, 13),
        termsVersion: TermsConfig.currentVersion,
      );

      expect(p.hasFiscalMapsShareLink, isTrue);
      expect(p.isComplete, isTrue);
      expect(p.isReadyForMainApp, isFalse);
    });

    test('pendiente de revisión no entra al panel principal', () {
      final p = _aliado(
        access: AccountAccessStatus.pendingReview,
        fiscalMapsUrl: 'https://maps.app.goo.gl/abc',
        termsAcceptedAt: DateTime.utc(2026, 6, 13),
        termsVersion: TermsConfig.currentVersion,
      );

      expect(p.needsPendingReviewScreen, isTrue);
      expect(p.isReadyForMainApp, isFalse);
    });
  });
}
