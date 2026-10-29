import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var currency = 'DIVISAS';
  final requests = <Uri>[];
  final row = <String, dynamic>{
    'id': 'order',
    'aliado_id': 'buyer',
    'importador_id': 'supplier',
    'product_id': 'product',
    'status': 'pendiente',
    'cantidad': 5,
    'precio_total_usd': 240,
    'precio_base_aliado_total': 240,
    'tasa_bcv_aplicada': 10,
    'total_ref': 260,
    'total_bs': 2600,
    'discount_rules': {'checkout_pricing_version': 1},
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.supabase.co',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false, detectSessionInUri: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
              jsonEncode({
                'access_token': 'fixture-token',
                'refresh_token': 'fixture-refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': 'buyer',
                  'aud': 'authenticated',
                  'app_metadata': {},
                  'user_metadata': {},
                  'created_at': '2026-10-29T00:00:00Z'
                },
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'});
        }
        requests.add(request.url);
        final selected = request.url.queryParameters['select'] ?? '';
        // Reproduce PostgREST projection: omitted columns are absent from the response.
        final data = {...row, 'metodo_pago_moneda': currency};
        data.removeWhere(
            (key, _) => !RegExp('(^|,)\\s*$key\\s*(,|\$)').hasMatch(selected));
        final single =
            request.headers['accept']?.contains('vnd.pgrst.object') ?? false;
        return http.Response(jsonEncode(single ? data : [data]), 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'buyer@example.test', password: 'fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());

  final loaders = <String, Future<List<TransactionRequestModel>> Function()>{
    'ally history': OrdersService.fetchMyTransactionRequests,
    'ally orders': OrdersService.fetchMyPedidosActivosYCerradosForAliado,
    'supplier active': OrdersService.fetchActiveTransactionRequestsForImporter,
    'supplier unified':
        OrdersService.fetchUnifiedTransactionRequestsForImporter,
    'admin all': OrdersService.fetchTransactionRequestsForAdmin,
    'admin active': OrdersService.fetchActiveTransactionRequestsForAdmin,
    'admin closed': OrdersService.fetchClosedTransactionRequestsForAdmin,
    'admin unified': OrdersService.fetchUnifiedTransactionRequestsForAdmin,
  };
  for (final entry in loaders.entries) {
    for (final mode in ['DIVISAS', 'BOLIVARES']) {
      test('${entry.key} reads frozen currency and amounts for $mode',
          () async {
        currency = mode;
        final order = (await entry.value()).single;
        expect(order.metodoPagoMoneda, mode);
        expect(order.amountCurrencyLabel, mode == 'DIVISAS' ? 'USD' : 'REF');
        expect(order.tasaBcvAplicada, 10);
        expect(order.totalRef, 260);
        expect(order.totalBs, 2600);
        expect(order.hasAppliedVolumeDiscount, isFalse);
        expect(
            order.metodosPagoPermitidos,
            mode == 'DIVISAS'
                ? contains('zelle_divisas')
                : contains('pago_movil'));
        expect(
            order.metodosPagoPermitidos,
            mode == 'DIVISAS'
                ? isNot(contains('pago_movil'))
                : isNot(contains('zelle_divisas')));
        expect(requests.last.queryParameters['select'],
            contains('metodo_pago_moneda'));
      });
    }
  }
  test('single order lookup uses the same frozen currency projection',
      () async {
    currency = 'DIVISAS';
    expect(
        (await OrdersService.fetchTransactionRequestById('order'))!
            .amountCurrencyLabel,
        'USD');
  });
  test(
      'volume label requires an applied discount, including historical snapshots',
      () {
    for (final pct in [0, 5]) {
      final order = TransactionRequestModel.fromJson({
        ...row,
        'discount_rules': {'applied_volume_discount_pct': pct}
      });
      expect(order.hasAppliedVolumeDiscount, pct > 0);
      expect(order.amountCurrencyLabel, 'REF');
    }
  });
}
