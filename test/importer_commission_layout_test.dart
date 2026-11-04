import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/commissions/importer_commission_settlements_section.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.supabase.co',
      anonKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false, autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final rows = [
          {
            'id': 'draft',
            'status': 'borrador',
            'period_start': '2026-10-12',
            'period_end': '2026-10-18',
            'total_commission_usd': 10,
            'line_count': 1
          },
          {
            'id': 'paid',
            'status': 'pagado',
            'period_start': '2026-07-27',
            'period_end': '2026-08-02',
            'total_commission_usd': 20,
            'line_count': 1
          },
        ];
        return http.Response(
            jsonEncode(request.url.path.endsWith('/commission_settlements')
                ? rows
                : request.url.path.endsWith('/transaction_requests')
                    ? [
                        {
                          'id': 'line',
                          'precio_total_usd': 200,
                          'comision_devengada_usd': 10,
                          'products': {
                            'name': 'Kit de embrague completo para moto 125 cc'
                          }
                        }
                      ]
                    : <String, dynamic>{}),
            200,
            headers: {'content-type': 'application/json'},
            request: request);
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  for (final width in [320.0, 1100.0]) {
    testWidgets('commission filters preserve totals and fit at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ImporterCommissionSettlementsSection()))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cortes de comisión B2B Conecta'));
      await tester.pumpAndSettle();
      expect(find.text('USD 11.60'), findsOneWidget);
      expect(find.text('USD 23.20'), findsOneWidget);
      final paid = find.widgetWithText(ChoiceChip, 'Pagado');
      await tester.ensureVisible(paid);
      await tester.tap(paid);
      await tester.pumpAndSettle();
      expect(find.text('USD 11.60'), findsNothing);
      expect(find.text('USD 23.20'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12/10/2026 — 18/10/2026').last);
      await tester.pumpAndSettle();
      expect(find.text('Ningún corte coincide con los filtros seleccionados.'),
          findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pumpAndSettle();
      expect(find.text('USD 11.60'), findsOneWidget);
      expect(find.text('USD 23.20'), findsNothing);
      final period = find.text('12/10/2026 — 18/10/2026').last;
      await tester.ensureVisible(period);
      await tester.tap(period);
      await tester.pumpAndSettle();
      expect(find.text('USD 11.60'), findsOneWidget);
      expect(find.text('Documento por emitir'), findsOneWidget);
      expect(find.text('Total estimado · ver desglose'), findsNothing);
      expect(find.text('Base de comisión'), findsOneWidget);
      expect(find.text('IVA 16 %'), findsOneWidget);
      expect(find.text('Ventas relacionadas · USD 200.00'), findsOneWidget);
      expect(
          find.text('Kit de embrague completo para moto 125 cc'), findsNothing);
      final included = find.text('Pedidos incluidos · 1');
      await tester.ensureVisible(included);
      await tester.tap(included);
      await tester.pumpAndSettle();
      expect(find.text('Kit de embrague completo para moto 125 cc'),
          findsOneWidget);
      expect(find.text('Venta'), findsOneWidget);
      expect(find.text('Comisión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
