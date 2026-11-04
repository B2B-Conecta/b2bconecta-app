import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/app/config/terms_config.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_service.dart';
import 'package:motolink_pro_app/features/profile/profile_overview.dart';
import 'package:motolink_pro_app/features/profile/importer_commercial_settings.dart';
import 'package:motolink_pro_app/core/layout/b2b_desktop_shell.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_count_card.dart';

void main() {
  final writes = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.supabase.co',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false),
        httpClient: MockClient((request) async {
          dynamic body = <String, dynamic>{};
          if (request.url.path.endsWith('/token')) {
            body = {
              'access_token': 'fixture',
              'refresh_token': 'fixture',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'supplier',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-11-04T00:00:00Z'
              }
            };
          } else if (request.url.path.endsWith('/profiles')) {
            if (request.method == 'PATCH') writes.add(request);
            body = {
              'id': 'supplier',
              'role': 'importador',
              'business_name': 'Proveedor',
              'rif': 'J-123',
              'account_access_status': 'active',
              'min_order_amount_ref': 90,
              'min_order_currency': 'usd'
            };
          } else if (request.url.path
              .endsWith('/importer_daily_store_notice')) {
            body = {'show': false, 'store_count': 4};
          } else if (request.url.path.endsWith('/commission_settlements')) {
            body = [];
          }
          return http.Response(jsonEncode(body), 200,
              request: request, headers: {'content-type': 'application/json'});
        }));
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'test@example.test', password: 'fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    writes.clear();
    MainShellTabController.consumeImporterCommissionPreferPendiente();
  });

  test('minimum order update changes only its two fields', () async {
    await ProfileService.updateMyMinimumOrder(amount: 25, currency: 'usd');
    expect(writes, hasLength(1));
    expect(jsonDecode(writes.single.body),
        {'min_order_amount_ref': 25, 'min_order_currency': 'usd'});
    expect(writes.single.url.queryParameters['id'], 'eq.supplier');
    await expectLater(
        ProfileService.updateMyMinimumOrder(
            amount: double.nan, currency: 'ref'),
        throwsArgumentError);
    expect(writes, hasLength(1));
  });

  test('business edits preserve commercial settings', () async {
    await ProfileService.upsertMyProfile(
        businessName: 'Proveedor editado',
        rif: 'J-123',
        role: 'importador',
        updateMinimumOrder: false);
    final payload = jsonDecode(writes.single.body) as Map;
    expect(payload['business_name'], 'Proveedor editado');
    expect(payload.containsKey('min_order_amount_ref'), isFalse);
    expect(payload.containsKey('min_order_currency'), isFalse);
  });

  for (final width in [320.0, 1100.0]) {
    testWidgets('profile and commercial editing remain usable at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profile = ProfileModel(
          id: 'supplier',
          role: 'importador',
          businessName: 'Proveedor',
          rif: 'J-123',
          phone: '+58 424 1234567',
          estado: 'Miranda',
          ciudad: 'Caracas',
          direccion: 'Dirección de prueba',
          fiscalMapsUrl: 'https://maps.google.com/?q=Caracas',
          accountAccessStatus: 'active',
          termsAcceptedAt: DateTime(2026),
          termsVersion: TermsConfig.currentVersion,
          minOrderAmountRef: 90,
          minOrderCurrency: 'usd');
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ProfileOverview(
                      profile: profile,
                      accountActionsInShell: width >= 900,
                      onEdit: () {},
                      onSignOut: () {})))));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta y seguridad'),
          width >= 900 ? findsNothing : findsOneWidget);
      expect(find.text('Cerrar sesión'),
          width >= 900 ? findsNothing : findsOneWidget);
      expect(find.text('Cuenta habilitada'), findsOneWidget);
      expect(find.text('Comisiones'), findsOneWidget);
      expect(find.text('Cortes de comisión B2B Conecta'), findsNothing);
      MainShellTabController.navigateToImporterPendingCommissions();
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Cortes de comisión B2B Conecta'), findsOneWidget);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ImporterCommercialSettings(profile: profile)))));
      await tester.pumpAndSettle();
      expect(find.text('Transportistas'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '25,50');
      await tester.tap(find.text('Cancelar').first);
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(find.text('90.00'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '25,50');
      await tester.tap(find.text('Guardar mínimo'));
      await tester.pumpAndSettle();
      expect(jsonDecode(writes.single.body)['min_order_amount_ref'], 25.5);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [1000.0, 1400.0]) {
    for (final role in ['aliado', 'importador']) {
      testWidgets('desktop account stays fixed for $role at $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var index = 0;
        var settingsOpened = 0;
        var signOutCalls = 0;
        final pendingSignOut = Completer<void>();
        final profile = ProfileModel(
            id: 'supplier',
            role: role,
            businessName: 'Proveedor',
            accountAccessStatus: 'active');
        await tester.pumpWidget(MaterialApp(
            home: StatefulBuilder(
                builder: (context, setState) => B2bDesktopShell(
                    selectedIndex: index,
                    onDestinationSelected: (value) =>
                        setState(() => index = value),
                    destinations: const [
                      ShellDestination(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home,
                          label: 'Inicio',
                          title: 'Inicio'),
                      ShellDestination(
                          icon: Icons.person_outline,
                          selectedIcon: Icons.person,
                          label: 'Perfil',
                          title: 'Perfil'),
                    ],
                    pages: [
                      ListView(
                          children: List.generate(
                              30,
                              (i) => SizedBox(
                                  height: 80, child: Text('Contenido $i')))),
                      SingleChildScrollView(
                          child: ProfileOverview(
                              profile: profile,
                              accountActionsInShell: true,
                              onEdit: () {},
                              onSignOut: () {})),
                    ],
                    profile: profile,
                    unreadNotifications: 0,
                    onNotificationTap: () {},
                    onOpenSettings: () => settingsOpened++,
                    onSignOut: () {
                      signOutCalls++;
                      return pendingSignOut.future;
                    },
                    railStatusBuilder: role == 'importador'
                        ? (extended) =>
                            ImporterStoreCountCard(extended: extended)
                        : null,
                    railBadgeLabel: 'Panel de prueba'))));
        await tester.pumpAndSettle();
        final logout = find.byIcon(Icons.logout);
        final footerPosition = tester.getCenter(logout);
        if (role == 'importador') expect(find.text('4'), findsOneWidget);
        await tester.drag(find.text('Contenido 0'), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.getCenter(logout), footerPosition);
        await tester.tap(find.text('Perfil').first);
        await tester.pumpAndSettle();
        expect(tester.getCenter(logout), footerPosition);
        expect(logout, findsOneWidget);
        if (role == 'importador') expect(find.text('4'), findsOneWidget);
        expect(find.text('Cuenta y seguridad'),
            width >= 1180 ? findsOneWidget : findsNothing);
        if (role == 'aliado') expect(find.text('Tu cuenta'), findsNothing);
        await tester.tap(find.byIcon(Icons.settings_outlined));
        expect(settingsOpened, 1);
        await tester.tap(logout);
        await tester.pump();
        await tester.tap(logout);
        expect(signOutCalls, 1);
        pendingSignOut.completeError(StateError('fixture'));
        await tester.pumpAndSettle();
        expect(find.text('No pudimos cerrar la sesión. Inténtalo de nuevo.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
