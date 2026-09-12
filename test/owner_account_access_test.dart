import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/owner_account_create_rules.dart';
import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/admin/owner_account_search.dart';
import 'package:motolink_pro_app/features/admin/owner_catalog_filter.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
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
          targetId: 'tienda minorista-1',
          targetIsOwner: false,
        ),
        isFalse,
      );
    });

    test('un borrador se puede activar; una activa no', () {
      expect(
        OwnerAccountRules.canActivateAccess(
          accountAccessStatus: AccountAccessStatus.draft,
        ),
        isTrue,
      );
      expect(
        OwnerAccountRules.canActivateAccess(
          accountAccessStatus: AccountAccessStatus.active,
        ),
        isFalse,
      );
      expect(
        OwnerAccountRules.canActivateAccess(
          accountAccessStatus: AccountAccessStatus.draft,
          deactivatedAt: DateTime.utc(2026, 9, 1),
        ),
        isFalse,
      );
    });

    test('el borrado definitivo solo confirma con el correo exacto', () {
      expect(
        OwnerAccountRules.hardDeleteConfirmMatches(
          typed: 'aliado1@motoconecta.seed',
          email: 'Aliado1@motoconecta.seed',
        ),
        isTrue,
      );
      expect(
        OwnerAccountRules.hardDeleteConfirmMatches(
          typed: 'aliado1',
          email: 'aliado1@motoconecta.seed',
        ),
        isFalse,
      );
      expect(
        OwnerAccountRules.hardDeleteConfirmMatches(
          typed: '  ',
          email: 'aliado1@motoconecta.seed',
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

    test('withAuthEmail adjunta correo sin perder el resto de la ficha', () {
      final p = ProfileModel(
        id: 'a1',
        role: 'aliado',
        businessName: 'Taller Sur',
        phone: '04121234567',
        ciudad: 'Valencia',
      );
      final withMail = p.withAuthEmail('tienda@example.com');
      expect(withMail.email, 'tienda@example.com');
      expect(withMail.phone, '04121234567');
      expect(withMail.businessName, 'Taller Sur');
      expect(p.email, isNull);
    });

    test('busqueda owner incluye correo, telefono y ciudad', () {
      final p = ProfileModel(
        id: 'a1',
        role: 'aliado',
        businessName: 'Taller Sur',
        rif: 'J-99887766',
        phone: '04121234567',
        email: 'tienda@example.com',
        ciudad: 'Valencia',
        estado: 'Carabobo',
      );
      expect(ownerAccountMatchesQuery(p, 'tienda@'), isTrue);
      expect(ownerAccountMatchesQuery(p, '0412'), isTrue);
      expect(ownerAccountMatchesQuery(p, 'valen'), isTrue);
      expect(ownerAccountMatchesQuery(p, '9988'), isTrue);
      expect(ownerAccountMatchesQuery(p, 'zzz'), isFalse);
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

    test('tienda minorista sigue necesitando active', () {
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

  group('OwnerAccountCreateRules', () {
    test('exige correo, contraseña coincidente y nombre', () {
      expect(
        OwnerAccountCreateRules.validateCreate(
          email: 'tienda@test.com',
          password: 'secret1',
          passwordConfirm: 'secret1',
          businessName: 'Tienda Norte',
          role: 'aliado',
        ),
        isNull,
      );
      expect(
        OwnerAccountCreateRules.validateCreate(
          email: 'mal',
          password: 'secret1',
          passwordConfirm: 'secret1',
          businessName: 'Tienda',
          role: 'aliado',
        ),
        isNotNull,
      );
      expect(
        OwnerAccountCreateRules.validateCreate(
          email: 'tienda@test.com',
          password: 'secret1',
          passwordConfirm: 'otra',
          businessName: 'Tienda',
          role: 'aliado',
        ),
        isNotNull,
      );
      expect(
        OwnerAccountCreateRules.validateDossier(businessName: '  '),
        isNotNull,
      );
    });
  });

  group('owner catalog filter', () {
    final items = [
      const PartModel(
        id: '1',
        nombre: 'Cable acelerador',
        sku: 'ALL-BAL-120',
        category: 'Transmisión',
        precio: 6,
        stock: 150,
        isActive: true,
      ),
      const PartModel(
        id: '2',
        nombre: 'Filtro aceite',
        sku: 'FLT-01',
        category: 'Motor',
        precio: 4,
        stock: 10,
        isActive: false,
      ),
    ];

    test('separa publicados y pausados y busca por sku', () {
      expect(
        ownerCatalogFilter(
          items: items,
          rawQuery: '',
          visibility: OwnerCatalogVisibility.publicados,
        ).map((p) => p.id),
        ['1'],
      );
      expect(
        ownerCatalogFilter(
          items: items,
          rawQuery: '',
          visibility: OwnerCatalogVisibility.pausados,
        ).map((p) => p.id),
        ['2'],
      );
      expect(
        ownerCatalogFilter(
          items: items,
          rawQuery: 'flt-01',
          visibility: OwnerCatalogVisibility.todos,
        ).single.id,
        '2',
      );
    });
  });
}
