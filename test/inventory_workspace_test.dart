import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/app/importer_shell_tabs.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/dashboard/importer_home_dashboard.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/inventory/importer_inventory_dashboard.dart';
import 'package:motolink_pro_app/features/inventory/inventory_product_tile.dart';
import 'package:motolink_pro_app/features/inventory/inventory_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var rows = <Map<String, dynamic>>[];
  final requests = <http.Request>[];
  Map<String, dynamic> product(int i) => {
        'id': 'product-$i',
        'owner_id': 'supplier',
        'name': 'Repuesto $i',
        'sku': 'SKU-$i',
        'price_usd': 52,
        'sale_price_usd': 48,
        'stock': i == 0 ? 0 : 25,
        'min_order_qty': 5,
        'stock_covers_min_order': i != 0,
        'is_active': true,
        'image_urls': <String>[],
        'category': i == 1000 ? 'Coronas especiales' : 'Motor',
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
          dynamic body;
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
              }
            };
          } else {
            requests.add(request);
            if (request.url.path.endsWith('/profiles')) {
              body = {
                'id': 'supplier',
                'business_name': 'Proveedor de prueba',
                'role': 'importador'
              };
            } else {
              final query = request.url.queryParameters;
              var matching = rows
                  .where(
                      (row) => query['stock'] != 'lte.0' || row['stock'] == 0)
                  .toList();
              if (query['category']?.startsWith('eq.') == true) {
                matching = matching
                    .where((row) =>
                        row['category'] == query['category']!.substring(3))
                    .toList();
              }
              final offset = int.tryParse(query['offset'] ?? '') ?? 0;
              final limit =
                  math.min(int.tryParse(query['limit'] ?? '') ?? 75, 75);
              body = matching.skip(offset).take(limit).toList();
            }
          }
          return http.Response(jsonEncode(body), 200,
              request: request, headers: {'content-type': 'application/json'});
        }));
    await Supabase.instance.client.auth.signInWithPassword(
        email: 'supplier@example.test', password: 'fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    rows = List.generate(3, product);
    requests.clear();
  });

  test('metrics and real categories include rows beyond the server page limit',
      () async {
    rows = List.generate(1001, product);
    final metrics = await InventoryService.fetchMyInventoryMetrics();
    expect(metrics.totalProducts, 1001);
    expect(metrics.categories, ['Coronas especiales', 'Motor']);
    expect(metrics.outOfStock, 1);
    expect(metrics.withoutPhotos, 1001);
    expect(requests.length, greaterThan(2));
    expect(
        requests
            .every((r) => r.url.queryParameters['owner_id'] == 'eq.supplier'),
        isTrue);
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });

  testWidgets(
      'inventory opens on products and filters do not reload business data',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ImporterInventoryDashboard())));
    await tester.pumpAndSettle();
    expect(find.text('Inicio rápido'), findsNothing);
    expect(find.text('Desempeño de ventas'), findsNothing);
    expect(find.byType(InventoryProductTile), findsWidgets);
    expect(tester.getTopLeft(find.byType(InventoryProductTile).first).dy,
        lessThan(300));
    final metricQueries = requests
        .where((r) => (r.url.queryParameters['select'] ?? '')
            .contains('stock_covers_min_order,category'))
        .length;
    await tester.ensureVisible(find.text('Sin stock').first);
    await tester.tap(find.text('Sin stock').first);
    await tester.pumpAndSettle();
    expect(
        requests.any((r) => r.url.queryParameters['stock'] == 'lte.0'), isTrue);
    expect(
        requests
            .where((r) => (r.url.queryParameters['select'] ?? '')
                .contains('stock_covers_min_order,category'))
            .length,
        metricQueries);
    expect(
        requests.any((r) =>
            r.url.path.contains('transaction_requests') ||
            r.url.path.contains('commission') ||
            r.url.path.contains('/rpc/')),
        isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real categories can be applied without changing product data',
      (tester) async {
    rows.add(product(1000));
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ImporterInventoryDashboard())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtrar productos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coronas especiales').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(
        requests.any((r) =>
            r.url.queryParameters['category'] == 'eq.Coronas especiales'),
        isTrue);
    expect(requests.every((r) => r.method == 'GET'), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Inicio owns business overview and links back to inventory',
      (tester) async {
    int? selected;
    MainShellTabController.register((index) => selected = index);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ImporterHomeDashboard(
                profile: ProfileModel(id: 'supplier', role: 'importador')))));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos por confirmar'), findsOneWidget);
    expect(find.text('Comisiones por pagar'), findsOneWidget);
    expect(find.text('Tu inventario'), findsOneWidget);
    expect(find.byType(InventoryProductTile), findsNothing);
    await tester.tap(find.text('Ver productos'));
    await tester.pump();
    expect(selected, ImporterShellTabs.inventario);
    expect(MainShellTabController.importerInventoryRequest.value, 'todos');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    MainShellTabController.unregister();
  });

  for (final width in [320.0, 390.0, 1100.0]) {
    for (final dark in [false, true]) {
      testWidgets('product actions stay accessible at $width dark=$dark',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppColors.brightness = dark ? Brightness.dark : Brightness.light;
        var shared = false;
        var deleted = false;
        final part = PartModel.fromJson({
          ...product(1),
          'name': 'Disco de freno delantero para motocicleta 245 mm'
        });
        await tester.pumpWidget(MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
                body: MediaQuery(
                    data: MediaQueryData(
                        size: Size(width, 900),
                        textScaler: const TextScaler.linear(1.3)),
                    child: InventoryProductTile(
                        part: part,
                        onEdit: () {},
                        onShare: () => shared = true,
                        onDelete: () => deleted = true,
                        onVisibilityChanged: (_) {})))));
        expect(find.byIcon(Icons.delete_outline), findsNothing);
        expect(find.text('52.00 REF'), findsOneWidget);
        expect(find.text('48.00 USD en divisas'), findsOneWidget);
        final options = find.byTooltip('Opciones de ${part.nombre}');
        await tester.tap(options);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compartir producto'));
        await tester.pumpAndSettle();
        expect(shared, isTrue);
        expect(deleted, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'importer shortcuts retain correct destinations after adding Inicio',
      (tester) async {
    int? selected;
    MainShellTabController.register((index) => selected = index);
    MainShellTabController.registerB2BNavigation(
        home: ImporterShellTabs.inicio,
        pedidos: ImporterShellTabs.pedidos,
        reputation: ImporterShellTabs.reputacion,
        profile: ImporterShellTabs.perfil);
    MainShellTabController.navigateToImporterInventory(filter: 'sin_stock');
    expect(selected, ImporterShellTabs.inventario);
    expect(MainShellTabController.importerInventoryRequest.value, 'sin_stock');
    MainShellTabController.navigateToImporterPedidosExplore('nuevos');
    expect(selected, ImporterShellTabs.pedidos);
    expect(
        MainShellTabController.consumeImporterPedidosExploreFilter(), 'nuevos');
    MainShellTabController.navigateToImporterPendingCommissions();
    expect(selected, ImporterShellTabs.perfil);
    expect(MainShellTabController.consumeImporterCommissionPreferPendiente(),
        isTrue);
    MainShellTabController.navigateToImporterInventoryForNotification();
    expect(selected, ImporterShellTabs.inventario);
    MainShellTabController.navigateToImporterHomeForNotification();
    expect(selected, ImporterShellTabs.inicio);
    await tester.pump();
    MainShellTabController.unregister();
  });
}
