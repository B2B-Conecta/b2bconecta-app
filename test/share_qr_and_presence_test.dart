import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/admin_catalog_coverage.dart';
import 'package:motolink_pro_app/features/admin/admin_user_monitoring_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_user_presence_section.dart';
import 'package:motolink_pro_app/features/admin/user_presence.dart';
import 'package:motolink_pro_app/features/catalog/importer_daily_store_notice.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_share_link.dart';
import 'package:motolink_pro_app/features/catalog/product_share_link.dart';
import 'package:motolink_pro_app/features/inventory/importer_onboarding_checklist.dart';
import 'package:motolink_pro_app/features/inventory/inventory_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  const id = '11111111-2222-3333-4444-555555555555';

  test('el QR de la vitrina usa la ruta pública y no lleva sesión', () {
    final url = ImporterStoreShareLink.urlFor(id);
    expect(url, 'https://app.b2bconecta.com.ve/vitrina/$id');
    expect(ImporterStoreShareLink.urlIsPublic(url), isTrue);
    expect(url.contains('token'), isFalse);
    expect(url.contains('access_token'), isFalse);
    expect(
      ImporterStoreShareLink.idFromUri(Uri.parse('$url?access_token=abc')),
      id,
    );
    expect(
      ImporterStoreShareLink.urlIsPublic('$url?access_token=abc'),
      isFalse,
    );
  });

  test('la ficha y la vitrina no se confunden', () {
    expect(
      ImporterStoreShareLink.idFromUri(
        Uri.parse(ProductShareLink.urlFor(id)),
      ),
      isNull,
    );
    expect(
      ProductShareLink.idFromUri(
        Uri.parse(ImporterStoreShareLink.urlFor(id)),
      ),
      isNull,
    );
  });

  test('el aviso diario no muestra cero ni un fallo', () {
    final hidden = ImporterDailyStoreNotice.decide(
      failed: false,
      serverSaysShow: true,
      storeCount: 0,
    );
    expect(hidden.show, isFalse);
    expect(hidden.message, isNull);

    final failed = ImporterDailyStoreNotice.decide(
      failed: true,
      serverSaysShow: true,
      storeCount: 12,
    );
    expect(failed.message, isNull);

    final shown = ImporterDailyStoreNotice.fromRpc({
      'show': true,
      'store_count': 42,
    });
    expect(shown.message, 'Ya hay 42 tiendas activas en B2B Conecta.');
  });

  test('en línea son los últimos 5 minutos y la consulta es solo admin', () {
    final now = DateTime(2026, 10, 15, 12);
    expect(
      userPresenceIsOnline(now.subtract(const Duration(minutes: 4)), now),
      isTrue,
    );
    expect(
      userPresenceIsOnline(now.subtract(const Duration(minutes: 6)), now),
      isFalse,
    );
    expect(userPresenceIsOnline(null, now), isFalse);
    expect(canQueryAdminPresence('administrador'), isTrue);
    expect(canQueryAdminPresence('aliado'), isFalse);
    expect(canQueryAdminPresence('importador'), isFalse);
  });

  test('la presencia agrupa por cuenta', () {
    final row = AdminUserPresenceRow.fromJson({
      'profile_id': id,
      'display_name': 'Ana',
      'business_name': 'Taller Ana',
      'role': 'aliado',
      'last_seen_at': '2026-10-15T16:00:00Z',
    });
    expect(row.profileId, id);
    expect(row.displayName, 'Ana');
  });

  test('el checklist usa perfil, pago, mínimo y publicación', () {
    final empty = ImporterOnboardingChecklist.evaluate(
      profile: const ProfileModel(id: id, role: 'importador'),
      metrics: InventoryMetrics.zero,
    );
    expect(empty.doneCount, 0);
    expect(empty.isComplete, isFalse);

    final ready = ImporterOnboardingChecklist.evaluate(
      profile: const ProfileModel(
        id: id,
        role: 'importador',
        businessName: 'Moto Mayor',
        rif: 'J-12345678-9',
        estado: 'Miranda',
        ciudad: 'Caracas',
        direccion: 'Calle 1',
        accountAccessStatus: 'active',
        acceptedPagoMetodos: ['zelle_divisas'],
        minOrderAmountRef: 50,
      ),
      metrics: const InventoryMetrics(
        totalProducts: 2,
        outOfStock: 0,
        paused: 0,
      ),
    );
    expect(ready.isComplete, isTrue);
    expect(ready.doneCount, 5);
  });

  testWidgets('la presencia lista 10 y permite 20', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final rows = [
      for (var i = 0; i < 25; i++)
        AdminUserPresenceRow(
          profileId: '$i',
          displayName: 'Cuenta $i',
          role: 'importador',
          businessName: 'Negocio $i',
          lastSeenAt: DateTime.now().subtract(Duration(seconds: i)),
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUserPresenceSection(loadRows: () async => rows),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Cuenta 0'), findsOneWidget);
    expect(find.text('Cuenta 9'), findsOneWidget);
    expect(find.text('Cuenta 10'), findsNothing);
    expect(find.text('1–10 de 25'), findsOneWidget);

    await tester.tap(find.text('20'));
    await tester.pump();

    expect(find.text('Cuenta 19'), findsOneWidget);
    expect(find.text('Cuenta 20'), findsNothing);
    expect(find.text('1–20 de 25'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la presencia se abre desde Ingresos', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUserMonitoringPanel(
            loadRows: ({role, required period}) async => const [],
            loadCatalogCoverage: () async => AdminCatalogCoverage.empty,
            loadPresence: () async => const [
              AdminUserPresenceRow(
                profileId: '1',
                displayName: 'Taller Norte',
                role: 'aliado',
                businessName: 'Taller Norte',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Presencia en línea'), findsNothing);
    await tester.tap(find.text('Ingresos (últimos 7 días)'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Presencia en línea'), findsOneWidget);
    expect(find.text('Taller Norte'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
