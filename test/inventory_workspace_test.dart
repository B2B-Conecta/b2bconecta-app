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
import 'package:motolink_pro_app/features/inventory/importer_priority_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var rows = <Map<String, dynamic>>[];
  int? storeCount = 4;
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
            if (request.url.path.endsWith('/importer_daily_store_notice')) {
              body = {'show': false, 'store_count': storeCount};
            } else if (request.url.path.endsWith('/profiles')) {
              body = {
                'id': 'supplier',
                'business_name': 'Proveedor de prueba',
                'role': 'importador'
              };
            } else {
              final query = request.url.queryParameters;
              var matching = rows.where((row) {
                final stock = row['stock'] as int;
                return switch (query['stock']) {
                  'lte.0' => stock <= 0,
                  'gt.0' => stock > 0,
                  _ => true,
                };
              }).toList();
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
    storeCount = 4;
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
    expect(find.text('Repuesto 0'), findsOneWidget);
    expect(find.text('Repuesto 1'), findsNothing);

    final inStock = find.widgetWithText(ChoiceChip, 'Con stock');
    await tester.ensureVisible(inStock);
    await tester.tap(inStock);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(inStock).selected, isTrue);
    expect(requests.last.url.queryParameters['stock'], 'gt.0');
    expect(find.text('Repuesto 0'), findsNothing);
    expect(find.text('Repuesto 1'), findsOneWidget);
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

  for (final width in [390.0, 1100.0]) {
    testWidgets(
        'inventory keeps search and filters visible on scroll at $width',
        (tester) async {
      rows = List.generate(15, product);
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: ImporterInventoryDashboard())));
      await tester.pumpAndSettle();

      final search = find.byType(TextField);
      final filter = find.byTooltip('Filtrar productos');
      final initialSearchTop = tester.getTopLeft(search).dy;
      final list = find.byType(CustomScrollView);
      await tester.drag(list, const Offset(0, -420));
      await tester.pumpAndSettle();

      final compactSearchTop = tester.getTopLeft(search).dy;
      expect(compactSearchTop, lessThan(initialSearchTop - 20));
      expect(compactSearchTop, greaterThanOrEqualTo(0));
      expect(filter.hitTestable(), findsOneWidget);
      expect(find.text('Todos').hitTestable(), findsOneWidget);

      tester.widget<CustomScrollView>(list).controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(search).dy, closeTo(initialSearchTop, 1));
      expect(tester.takeException(), isNull);
    });
  }

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

  for (final layout in [(320.0, 1.0), (390.0, 1.0), (1100.0, 1.0)]) {
    testWidgets('Inicio summary fits ${layout.$1} with text scale ${layout.$2}',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected;
      MainShellTabController.register((index) => selected = index);
      MainShellTabController.registerB2BNavigation(
          home: ImporterShellTabs.inicio,
          pedidos: ImporterShellTabs.pedidos,
          reputation: ImporterShellTabs.reputacion,
          profile: ImporterShellTabs.perfil);
      addTearDown(MainShellTabController.unregister);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(
                      size: Size(layout.$1, 900),
                      textScaler: TextScaler.linear(layout.$2)),
                  child: const ImporterHomeDashboard(
                      profile:
                          ProfileModel(id: 'supplier', role: 'importador'))))));
      await tester.pumpAndSettle();
      final cards = find.byType(ImporterPriorityCard);
      expect(cards, findsNWidgets(3));
      expect(find.text('Tiendas activas'), findsOneWidget);
      expect(find.descendant(of: cards.at(2), matching: find.text('4')),
          findsOneWidget);
      expect(
          tester.getTopLeft(cards.at(0)).dy, tester.getTopLeft(cards.at(2)).dy);
      expect(tester.getRect(cards.at(2)).right, lessThanOrEqualTo(layout.$1));
      if (layout.$1 >= 390) {
        expect(tester.getSize(cards.first).height,
            lessThanOrEqualTo(tester.getSize(cards.first).width * 1.3));
      }
      await tester.tap(find.text('Pedidos por confirmar'));
      await tester.pump();
      expect(selected, ImporterShellTabs.pedidos);
      expect(MainShellTabController.consumeImporterPedidosExploreFilter(),
          'nuevos');
      await tester.tap(find.text('Comisiones por pagar'));
      await tester.pump();
      expect(selected, ImporterShellTabs.perfil);
      expect(MainShellTabController.consumeImporterCommissionPreferPendiente(),
          isTrue);
      storeCount = 9;
      await tester.tap(find.byTooltip('Actualizar resumen'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: cards.at(2), matching: find.text('9')),
          findsOneWidget);
      storeCount = null;
      await tester.tap(find.byTooltip('Actualizar resumen'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: cards.at(2), matching: find.text('—')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('summary labels remain readable with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: ImporterPriorityActions(actions: [
                      ImporterPriorityAction(
                          label: 'Pedidos por confirmar',
                          value: '1000',
                          icon: Icons.inbox_outlined),
                      ImporterPriorityAction(
                          label: 'Comisiones por pagar',
                          value: '20',
                          icon: Icons.receipt_long_outlined),
                      ImporterPriorityAction(
                          label: 'Tiendas activas',
                          value: '99999',
                          icon: Icons.storefront_outlined),
                    ]))))));
    expect(find.text('Pedidos por confirmar'), findsOneWidget);
    expect(find.text('Comisiones por pagar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [720.0, 1100.0, 1440.0]) {
    testWidgets('desktop summary combines inventory in one row at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected;
      MainShellTabController.register((index) => selected = index);
      addTearDown(MainShellTabController.unregister);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: ImporterHomeDashboard(
                  embedInDesktopShell: true,
                  profile: ProfileModel(id: 'supplier', role: 'importador')))));
      await tester.pumpAndSettle();
      final cards = find.byType(ImporterPriorityCard);
      final inventory =
          find.byKey(const ValueKey('importer-inventory-summary'));
      expect(cards, findsNWidgets(2));
      expect(inventory, findsOneWidget);
      expect(find.text('Tiendas activas'), findsNothing);
      expect(
          requests.any((request) =>
              request.url.path.endsWith('/importer_daily_store_notice')),
          isFalse);
      expect(
          tester.getTopLeft(cards.first).dy, tester.getTopLeft(inventory).dy);
      if (width >= 1100) {
        expect(tester.getSize(cards.first).height, lessThan(180));
      }
      expect(tester.getRect(inventory).right, lessThanOrEqualTo(width));
      await tester.tap(find.text('1 sin stock'));
      await tester.pump();
      expect(selected, ImporterShellTabs.inventario);
      expect(
          MainShellTabController.importerInventoryRequest.value, 'sin_stock');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
