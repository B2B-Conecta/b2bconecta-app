import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/inventory/inventory_qr_screen.dart';
import 'package:motolink_pro_app/features/inventory/inventory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rows = List.generate(
      3,
      (i) => {
            'id': '11111111-2222-3333-4444-55555555555$i',
            'sku': i < 2 ? '0007' : '0008',
            'name': ['Aceite A', 'Aceite B', 'Bujía C'][i],
            'image_urls': <String>[],
          });
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.supabase.co',
      anonKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false, autoRefreshToken: false),
      httpClient: MockClient((request) async {
        dynamic body = [];
        if (request.url.path.endsWith('/token')) {
          body = {
            'access_token': 'fixture-token',
            'refresh_token': 'fixture-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'supplier',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-11-03T00:00:00Z'
            },
          };
        } else if (request.url.path.endsWith('/products')) {
          final query = request.url.queryParameters;
          final cursor = query['id']?.replaceFirst('gt.', '');
          final matching = rows
              .where((r) =>
                  cursor == null || (r['id']! as String).compareTo(cursor) > 0)
              .toList();
          matching.sort(
              (a, b) => (a['id']! as String).compareTo(b['id']! as String));
          final ordered = (query['order'] ?? '').startsWith('id.asc')
              ? matching
              : matching.reversed;
          // Simulate a server cap below the requested page size.
          final limit = int.parse(query['limit'] ?? '500');
          body = ordered.take(limit < 2 ? limit : 2).toList();
        }
        return http.Response(jsonEncode(body), 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
        email: 'supplier@example.test', password: 'fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(home: InventoryQrScreen(onInventoryChanged: () {})));
    await tester.pumpAndSettle();
  }

  Finder tile(String name) => find.ancestor(
      of: find.text(name), matching: find.byType(CheckboxListTile));
  void selected(WidgetTester tester, List<bool> expected) {
    for (var i = 0; i < rows.length; i++) {
      expect(
          tester
              .widget<CheckboxListTile>(tile(rows[i]['name']! as String))
              .value,
          expected[i]);
    }
  }

  test('las páginas del inventario avanzan sin repetir ni omitir productos',
      () async {
    final loaded = await InventoryService.readMyInventoryPages('id,sku,name')
        .expand((page) => page)
        .toList();
    expect(
        loaded.map((r) => r['id']).toList(), rows.map((r) => r['id']).toList());
    expect(loaded.map((r) => r['id']).toSet().length, rows.length);
    final limited = await InventoryService.readMyInventoryPages('id', limit: 2)
        .expand((page) => page)
        .toList();
    expect(limited.map((r) => r['id']).toList(),
        rows.take(2).map((r) => r['id']).toList());
  });

  testWidgets('marcar o desmarcar una fila no cambia las otras',
      (tester) async {
    await open(tester);
    await tester.ensureVisible(tile('Aceite A'));
    await tester.tap(find.text('Aceite A'));
    await tester.pumpAndSettle();
    selected(tester, [true, false, false]);
    expect(find.text('Descargar etiquetas (1)'), findsOneWidget);
    await tester.tap(find.text('Aceite B'));
    await tester.pumpAndSettle();
    selected(tester, [true, true, false]);
    expect(find.text('Descargar etiquetas (2)'), findsOneWidget);
    await tester.tap(find.text('Aceite A'));
    await tester.pumpAndSettle();
    selected(tester, [false, true, false]);
    expect(find.text('Descargar etiquetas (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la casilla individual no activa la selección de resultados',
      (tester) async {
    await open(tester);
    final checkbox =
        find.descendant(of: tile('Aceite A'), matching: find.byType(Checkbox));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    selected(tester, [true, false, false]);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    selected(tester, [false, false, false]);
    expect(find.text('Descargar etiquetas (0)'), findsOneWidget);
  });

  testWidgets(
      'seleccionar resultados respeta el filtro y conserva otras selecciones',
      (tester) async {
    await open(tester);
    await tester.ensureVisible(tile('Bujía C'));
    await tester.tap(find.text('Bujía C'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Aceite');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar resultados (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Descargar etiquetas (3)'), findsOneWidget);
    await tester.tap(find.text('Quitar selección visible'));
    await tester.pumpAndSettle();
    expect(find.text('Descargar etiquetas (1)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.ensureVisible(tile('Bujía C'));
    selected(tester, [false, false, true]);
  });
}
