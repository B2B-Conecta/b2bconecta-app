import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/payments/aliado_order_pago_section.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final json = <String, dynamic>{
    'id': '7b7baafd-0c56-4ae6-9509-b11af3d6fc2a',
    'aliado_id': 'c2000001-0000-4000-8000-000000000001',
    'importador_id': 'c1000001-0000-4000-8000-000000000001',
    'product_id': '683b666d-13ce-43ce-9a5c-10e36a72c7df',
    'status': 'pendiente',
    'cantidad': 5,
    'precio_total_usd': 47.5,
    'precio_base_aliado_total': 47.5,
    'precio_unitario_proveedor': 9.5,
    'precio_unitario_aliado': 9.5,
    'metodo_pago_moneda': 'BOLIVARES',
    'tasa_bcv_aplicada': 889.2553,
    'total_ref': 47.5,
    'total_bs': 42239.63,
    'destino_entrega_usa_perfil': true,
    'checkout_group_id': '09943998-d654-485e-9027-e3066afd3fc3',
    'discount_rules': {
      'checkout_ref_unit': 9.5,
      'checkout_usd_unit': 8.5,
      'checkout_pricing_version': 1,
      'checkout_payment_currency': 'BOLIVARES',
    },
    'commission_rate_snapshot': 0.05,
    'carrier_decision': 'not_applicable',
    'cancelado_por_aliado': false,
    'anulado_por_motolink': false,
    'importador': {
      'id': 'c1000001-0000-4000-8000-000000000001',
      'business_name': 'Repuestos Delta Caracas C.A.',
      'accepted_pago_metodos': [
        'zelle_divisas',
        'pago_movil',
        'usdt',
        'transferencia',
        'efectivo',
      ],
      'pago_metodo_instrucciones': {
        'pago_movil':
            'Banco: Banco de Venezuela\nTeléfono: +58 424-1000001\nCédula/RIF del titular: J-401234567\nTitular: Repuestos Delta Caracas C.A.',
      },
      'pago_solo_divisas': false,
      'latitude': 10.4969,
      'longitude': -66.8488,
    },
    'products': {
      'name': 'Aceite',
      'sku': 'SKU-1',
      'discount_rules': null,
    },
  };

  testWidgets('pago section with checkout snapshot builds in dark', (tester) async {
    FlutterError.onError = (details) {
      // ignore: avoid_print
      print('FLUTTER_ERROR: ${details.exceptionAsString()}\n${details.stack}');
      FlutterError.presentError(details);
    };

    AppColors.brightness = Brightness.dark;
    final request = TransactionRequestModel.fromJson(json);
    expect(request.metodosPagoPermitidos, contains(PagoMetodo.pagoMovil));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppDarkTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AliadoOrderPagoSection(
              request: request,
              onChanged: () {},
              suppressPrimaryTitle: true,
              pagoBundleLines: [request],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Datos para'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.textContaining('Banco de Venezuela'), findsOneWidget);
  });
}
