import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

ProfileModel _admin({
  String id = 'owner-1',
  bool isOwner = false,
  DateTime? deactivatedAt,
  String? access = AccountAccessStatus.active,
  String? businessName = 'B2B Conecta',
  String? rif = 'J-123',
}) {
  return ProfileModel(
    id: id,
    role: 'administrador',
    businessName: businessName,
    rif: rif,
    isOwner: isOwner,
    deactivatedAt: deactivatedAt,
    accountAccessStatus: access,
  );
}

void main() {
  group('OwnerAccountRules', () {
    test('solo el owner gestiona a terceros, nunca a sí mismo ni a otro owner', () {
      expect(
        OwnerAccountRules.canManageTarget(
          viewerIsOwner: true,
          viewerId: 'owner-1',
          targetId: 'admin-2',
          targetIsOwner: false,
        ),
        isTrue,
      );
      expect(
        OwnerAccountRules.canManageTarget(
          viewerIsOwner: true,
          viewerId: 'owner-1',
          targetId: 'owner-1',
          targetIsOwner: true,
        ),
        isFalse,
      );
      expect(
        OwnerAccountRules.canManageTarget(
          viewerIsOwner: true,
          viewerId: 'owner-1',
          targetId: 'owner-2',
          targetIsOwner: true,
        ),
        isFalse,
      );
      expect(
        OwnerAccountRules.canManageTarget(
          viewerIsOwner: false,
          viewerId: 'admin-2',
          targetId: 'aliado-1',
          targetIsOwner: false,
        ),
        isFalse,
      );
    });

    test('etiqueta de baja lógica vs bloqueo, sin Superadmin', () {
      expect(
        OwnerAccountRules.statusLabelEs(
          role: 'administrador',
          accountAccessStatus: AccountAccessStatus.active,
          deactivatedAt: DateTime.utc(2026, 8, 1),
        ),
        'Eliminada',
      );
      expect(
        OwnerAccountRules.statusLabelEs(
          role: 'administrador',
          accountAccessStatus: AccountAccessStatus.rejected,
        ),
        'Bloqueada',
      );
      expect(
        OwnerAccountRules.statusLabelEs(
          role: 'aliado',
          accountAccessStatus: AccountAccessStatus.active,
        ),
        'Activa',
      );
    });
  });

  group('acceso de cuenta', () {
    test('admin activo entra; bloqueado o con baja lógica no', () {
      expect(_admin().hasActiveAccountAccess, isTrue);
      expect(_admin().isReadyForMainApp, isTrue);

      final blocked = _admin(access: AccountAccessStatus.rejected);
      expect(blocked.hasActiveAccountAccess, isFalse);
      expect(blocked.isReadyForMainApp, isFalse);

      final deleted = _admin(deactivatedAt: DateTime.utc(2026, 8, 27));
      expect(deleted.hasActiveAccountAccess, isFalse);
      expect(deleted.isReadyForMainApp, isFalse);
      expect(deleted.isDeactivated, isTrue);
    });

    test('fromJson lee is_owner, deactivated_at y email', () {
      final p = ProfileModel.fromJson({
        'id': 'u1',
        'role': 'administrador',
        'business_name': 'Ops',
        'rif': 'J-9',
        'is_owner': true,
        'deactivated_at': '2026-08-27T12:00:00Z',
        'email': 'ops@example.com',
        'account_access_status': 'rejected',
      });
      expect(p.isOwner, isTrue);
      expect(p.email, 'ops@example.com');
      expect(p.deactivatedAt, isNotNull);
      expect(p.hasActiveAccountAccess, isFalse);
    });

    test('aliado sigue necesitando active', () {
      final aliado = ProfileModel(
        id: 'a1',
        role: 'aliado',
        businessName: 'Taller',
        rif: 'J-2',
        estado: 'Miranda',
        ciudad: 'Caracas',
        direccion: 'Calle 1',
        fiscalMapsUrl: 'https://maps.google.com/?q=1',
        accountAccessStatus: AccountAccessStatus.active,
      );
      expect(aliado.hasActiveAccountAccess, isTrue);

      final draft = ProfileModel(
        id: 'a2',
        role: 'aliado',
        accountAccessStatus: AccountAccessStatus.draft,
      );
      expect(draft.hasActiveAccountAccess, isFalse);
    });
  });
}
