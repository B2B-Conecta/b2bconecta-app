import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/dashboard/aliado_home_service.dart';

void main() {
  final requests = <http.Request>[];
  var rankingFails = false;
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
          dynamic data = <String, dynamic>{};
          var status = 200;
          if (request.url.path.endsWith('/aliado_home_product_selection')) {
            if (rankingFails) {
              data = {'code': 'PGRST202', 'message': 'migration missing'};
              status = 404;
            } else {
              data = {
                'buy_again': ['second', 'gone', 'first'],
                'best_sellers': ['first', 'second']
              };
            }
          } else if (request.url.path.endsWith('/aliado_catalog_categories')) {
            data = [
              {'category': 'Frenos'},
              {'category': 'Aceite'}
            ];
          } else if (request.url.path
              .endsWith('/get_active_promo_campaigns_for_aliado')) {
            data = [];
          } else if (request.url.path.endsWith('/profiles')) {
            data = [
              {'id': 'supplier', 'business_name': 'Proveedor actual'},
              {'id': 'unpublished', 'business_name': 'Sin catálogo'},
            ];
          } else if (request.url.path.endsWith('/products')) {
            // El servidor puede entregar las filas en cualquier orden; una dejó de estar disponible.
            data = [
              for (final id in ['first', 'second'])
                {
                  'id': id,
                  'owner_id': 'supplier',
                  'name': id,
                  'price_usd': 12,
                  'sale_price_usd': 10,
                  'stock': 20,
                  'is_active': true,
                  'min_order_qty': 5,
                  'profiles': {'business_name': 'Proveedor actual'},
                }
            ];
          }
          return http.Response(jsonEncode(data), status,
              request: request, headers: {'content-type': 'application/json'});
        }));
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    requests.clear();
    rankingFails = false;
  });

  test('home keeps server ranking, rechecks current stock and retains REF/USD',
      () async {
    final home = await AliadoHomeService.load();
    expect(home.errors, isEmpty);
    expect(home.buyAgain.map((p) => p.id), ['second', 'first']);
    expect(home.bestSellers.map((p) => p.id), ['first', 'second']);
    expect(home.buyAgain.first.precio, 12);
    expect(home.buyAgain.first.salePriceUsd, 10);
    expect(home.buyAgain.first.ownerBusinessName, 'Proveedor actual');
    expect(home.suppliers.map((supplier) => supplier.id), ['supplier']);
    expect(home.newArrivals.map((part) => part.id), ['first', 'second']);
    final query = requests
        .singleWhere((r) =>
            r.url.path.endsWith('/products') &&
            r.url.queryParameters.containsKey('id'))
        .url
        .queryParameters;
    expect(query['id'], contains('first'));
    expect(query['id'], contains('second'));
    expect(query['is_active'], 'eq.true');
    expect(query['stock_covers_min_order'], 'eq.true');
    expect(requests.any((r) => r.url.path.contains('transaction_requests')),
        isFalse);
  });

  test('missing migration preserves categories and reports the missing ranking',
      () async {
    rankingFails = true;
    final home = await AliadoHomeService.load();
    expect(home.buyAgain, isEmpty);
    expect(home.bestSellers, isEmpty);
    expect(home.errors, ['tus compras y los más vendidos']);
    expect(
      home.categories.map((c) => c.label),
      ['Frenos', 'Lubricantes y mantenimiento'],
    );
    expect(
        requests.any((r) =>
            r.url.path.endsWith('/products') &&
            r.url.queryParameters.containsKey('id')),
        isFalse);
  });
}
