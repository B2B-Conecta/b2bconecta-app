import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_expandable_order_card.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_aliado_solicitud_section.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

TransactionRequestModel _order(String id, String mode) =>
    TransactionRequestModel.fromJson({
      'id': id,
      'aliado_id': 'buyer',
      'importador_id': 'supplier',
      'product_id': 'part-$id',
      'status': 'pendiente',
      'cantidad': 5,
      'precio_total_usd': mode == 'DIVISAS' ? 240 : 260,
      'precio_base_aliado_total': mode == 'DIVISAS' ? 240 : 260,
      'metodo_pago_moneda': mode,
      'tasa_bcv_aplicada': 10,
      'total_ref': 260,
      'total_bs': 2600,
      'discount_rules': {'checkout_pricing_version': 1},
      'products': {'name': 'Disco EBC $id'},
      'importador': {'business_name': 'Proveedor de prueba'},
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.supabase.co',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false));
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final mode in ['DIVISAS', 'BOLIVARES']) {
    final currency = mode == 'DIVISAS' ? 'USD' : 'REF';
    final amount = mode == 'DIVISAS' ? '240.00' : '260.00';
    for (final grouped in [false, true]) {
      testWidgets(
          'ally ${grouped ? 'grouped' : 'single'} card labels $mode correctly',
          (tester) async {
        final lines = [_order('one', mode), if (grouped) _order('two', mode)];
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
          body: SingleChildScrollView(
              child: AliadoExpandableOrderCard(
            request: lines.first,
            checkoutGroupLines: grouped ? lines : null,
            expanded: false,
            onToggle: () {},
            statusLabel: 'Pendiente',
          )),
        )));
        final total =
            grouped ? (double.parse(amount) * 2).toStringAsFixed(2) : amount;
        expect(find.textContaining('$total $currency'), findsWidgets);
        expect(
            find.textContaining('descuentos volumen en ficha'), findsNothing);
        if (currency == 'USD') {
          expect(find.textContaining('$amount REF'), findsNothing);
          expect(find.textContaining('$total REF'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('supplier and admin product breakdown preserves $mode currency',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: TransactionRequestProductosDesgloseSection(
            lines: [_order('one', mode)]),
      )));
      expect(find.textContaining('$amount $currency'), findsWidgets);
      if (currency == 'USD') {
        expect(find.textContaining('240.00 REF'), findsNothing);
        expect(find.text('Precios acordados para pago en divisas (USD).'),
            findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
