import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/home_screen.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  final initialRows = Completer<http.Response>();
  var initialStarted = false;
  var searched = false;
  http.Response response(dynamic data, http.Request request) => http.Response(
      jsonEncode(data), 200,
      request: request,
      headers: {'content-type': 'application/json', 'content-range': '0-0/1'});
  Map<String, dynamic> product(String id, String name) => {
        'id': id,
        'name': name,
        'price_usd': 12,
        'stock': 30,
        'is_active': true,
        'min_order_qty': 5,
      };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.supabase.co',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/search_catalog_product_ids')) {
            return response([
              {'product_id': 'oil', 'score': 1.0}
            ], request);
          }
          if (path.endsWith('/get_active_promo_product_discounts')) {
            return response({}, request);
          }
          final select = request.url.queryParameters['select'] ?? '';
        if (path.endsWith('/products') && select.startsWith('*')) {
            if (request.url.queryParameters.containsKey('id')) {
              searched = true;
              return response([product('oil', 'Aceite de moto')], request);
            }
            initialStarted = true;
            return initialRows.future;
          }
          return response([], request);
        }));
  });
  tearDownAll(() => Supabase.instance.dispose());
  tearDown(MainShellTabController.unregister);

  testWidgets(
      'late initial catalog response cannot overwrite a search from Inicio',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(
            profile: ProfileModel(id: 'retailer', role: 'aliado'),
            homeRole: AppHomeRole.aliado,
            embedInDesktopShell: true)));
    await tester.pump();
    expect(initialStarted, isTrue);
    MainShellTabController.navigateToAliadoCatalog(
        filters: const CatalogFilters(searchQuery: 'aceite'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(searched, isTrue);
    initialRows.complete(response(
        [product('old', 'LED de otra consulta')],
        http.Request(
            'GET', Uri.parse('https://fixture.supabase.co/rest/v1/products'))));
    await tester.pumpAndSettle();
    expect(find.text('Aceite de moto'), findsOneWidget);
    expect(find.text('LED de otra consulta'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
