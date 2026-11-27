import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_entry.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
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
                'id': 'ally',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-11-01T00:00:00Z'
              }
            };
          } else if (request.url.path.endsWith('/profiles')) {
            body = {
              'id': 'ally',
              'role': 'aliado',
              'fiscal_maps_url': 'https://maps.app.goo.gl/test'
            };
          } else {
            body = 'master-order';
          }
          return http.Response(jsonEncode(body), 200,
              headers: {'content-type': 'application/json'}, request: request);
        }));
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'qa@example.test', password: 'fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(requests.clear);

  test(
      'mixed checkout makes one atomic RPC with complete per-supplier currency map',
      () async {
    final result =
        await OrdersService.checkoutMultiImportadorCart(lines: const [
      {'product_id': 'part', 'cantidad': 5}
    ], currencyByImportador: const {
      'one': 'DIVISAS',
      'two': 'BOLIVARES'
    }, promoByImportador: const {
      'one': 'campaign'
    }, applyCreditByImportador: const {
      'two': true
    }, carriersByImportador: const {
      'one': {'carrier_id': 'carrier', 'driver_id': null}
    });
    expect(result, 'master-order');
    final calls = requests.where((r) => r.url.path.contains('/rpc/')).toList();
    expect(calls, hasLength(1));
    expect(calls.single.url.path, endsWith('/aliado_checkout_proveedores_v1'));
    final payload = jsonDecode(calls.single.body);
    expect(payload['p_moneda_by_importador'],
        {'one': 'DIVISAS', 'two': 'BOLIVARES'});
    expect(payload['p_apply_credit_by_importador'], {'two': true});
    expect(payload['p_promo_by_importador'], {'one': 'campaign'});
    expect(payload['p_carriers_by_importador']['one']['carrier_id'], 'carrier');
  });
  test('uniform choices and desktop use the existing global-currency RPC',
      () async {
    await OrdersService.checkoutMultiImportadorCart(lines: const [
      {'product_id': 'part', 'cantidad': 5}
    ], currencyByImportador: const {
      'one': 'DIVISAS',
      'two': 'DIVISAS'
    });
    final request = requests.where((r) => r.url.path.contains('/rpc/')).single;
    expect(
        request.url.path, endsWith('/aliado_checkout_multi_importador_moneda'));
    expect(jsonDecode(request.body)['p_moneda'], 'DIVISAS');
    expect(jsonDecode(request.body).containsKey('p_moneda_by_importador'),
        isFalse);
  });
  test('mobile always sends idempotent v2 RPC even with one uniform currency',
      () async {
    await OrdersService.checkoutMultiImportadorCart(
        lines: const [
          {'product_id': 'part', 'cantidad': 5}
        ],
        currencyByImportador: const {'one': 'DIVISAS'},
        requestId: 'request-one',
        savedAddressId: 'address-one',
        deliveryByImportador: const {
          'one': {'mode': 'PICKUP', 'location_id': 'pickup-one'}
        });
    final request = requests.where((r) => r.url.path.contains('/rpc/')).single;
    expect(request.url.path, endsWith('/aliado_checkout_confirmar_v2'));
    final payload = jsonDecode(request.body);
    expect(payload['p_request_id'], 'request-one');
    expect(payload['p_saved_address_id'], 'address-one');
    expect(payload['p_moneda_by_importador'], {'one': 'DIVISAS'});
    expect(payload['p_delivery_by_importador']['one']['location_id'],
        'pickup-one');
    expect(payload.containsKey('p_moneda'), isFalse);
  });
  test('unknown currency never reaches checkout RPC', () async {
    await expectLater(
        OrdersService.checkoutMultiImportadorCart(lines: const [
          {'product_id': 'part', 'cantidad': 5}
        ], currencyByImportador: const {
          'one': 'EUR'
        }),
        throwsArgumentError);
    expect(requests.where((r) => r.url.path.contains('/rpc/')), isEmpty);
  });
  test('order list retains the separate amounts of a mixed-currency order', () {
    TransactionRequestModel line(
            String id, String currency, double total, double? bs) =>
        TransactionRequestModel(
            id: id,
            aliadoId: 'ally',
            ownerId: id,
            productId: 'part',
            status: 'pendiente',
            cantidad: 5,
            precioUnitarioProveedor: 20,
            precioUnitarioAliado: 20,
            precioTotal: total,
            precioBaseAliadoTotal: total,
            metodoPagoMoneda: currency,
            totalBs: bs,
            discountRules: {'checkout_pricing_version': 1});
    final entries = [
      line('one', 'DIVISAS', 90, 1000),
      line('two', 'BOLIVARES', 100, 1000)
    ];
    expect(orderAmountCurrency(entries), 'MIXTO');
    expect(OrderListEntry(entries).amount, '90.00 USD + Bs 1.000,00');
    expect(OrderListEntry(entries).bolivares, isNull);
  });
}
