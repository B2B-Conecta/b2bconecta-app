import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/logistics/importer_pickup_locations_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var enabled = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.supabase.co',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          dynamic body;
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
                'created_at': '2026-11-01T00:00:00Z'
              }
            };
          } else if (request.url.path
              .endsWith('/list_importer_pickup_locations')) {
            body = [
              {
                'id': 'location-one',
                'importador_id': 'supplier',
                'label': 'Almacén principal',
                'estado': 'Miranda',
                'ciudad': 'Caracas',
                'direccion': 'Local 123',
                'maps_url': 'https://maps.app.goo.gl/fixture',
                'is_active': true,
                'is_default': true,
                'customer_pickup_enabled': enabled,
                'customer_pickup_instructions': 'Lunes a viernes'
              }
            ];
          } else if (request.url.path.endsWith('/set_customer_pickup_offer')) {
            enabled = jsonDecode(request.body)['p_enabled'] == true;
          }
          return http.Response(jsonEncode(body), 200,
              headers: {'content-type': 'application/json; charset=utf-8'},
              request: request);
        }));
    await Supabase.instance.client.auth.signInWithPassword(
        email: 'supplier@example.test', password: 'fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets(
      'supplier explicitly enables client pickup without overflowing mobile',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body:
                SingleChildScrollView(child: ImporterPickupLocationsPanel()))));
    await tester.pumpAndSettle();
    expect(
        requests.where(
            (r) => r.url.path.endsWith('/list_importer_pickup_locations')),
        hasLength(1));
    expect(find.textContaining('type '), findsNothing);
    expect(find.text('Almacén principal'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
    final offer = find.text('Ofrecer retiro a clientes');
    await tester.ensureVisible(offer);
    await tester.tap(offer);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lunes a viernes de 9 a 5');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Retiro para clientes · Activo'), findsOneWidget);
    final request = requests
        .singleWhere((r) => r.url.path.endsWith('/set_customer_pickup_offer'));
    expect(jsonDecode(request.body), {
      'p_location_id': 'location-one',
      'p_enabled': true,
      'p_instructions': 'Lunes a viernes de 9 a 5'
    });
    expect(tester.takeException(), isNull);
  });
}
