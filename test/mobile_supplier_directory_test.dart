import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'package:motolink_pro_app/core/layout/aliado_bottom_nav.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/catalog/mobile_supplier_visuals.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/aliado_product_card.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile_screen.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/supplier_directory_screen.dart';
import 'package:motolink_pro_app/features/catalog/supplier_directory_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

const directoryViewer =
    ProfileModel(id: 'buyer', role: 'aliado', accountAccessStatus: 'active');
const directoryStore = ImporterStoreProfile(
    id: 'supplier',
    businessName: 'Repuestos Delta Caracas C.A.',
    ciudad: 'Caracas',
    estado: 'Distrito Capital',
    rif: 'J-12345678',
    phone: '04141234567',
    direccion: 'Avenida Francisco de Miranda, Los Ruices',
    fiscalMapsUrl: 'https://maps.google.com/?q=Caracas',
    ratingAvg: 4.8,
    ratingCount: 24,
    minOrderAmountRef: 100,
    acceptedPagoMetodos: ['pago_movil', 'transferencia']);
const directoryProduct = PartModel(
    id: 'product',
    ownerId: 'supplier',
    nombre: 'Pastillas de freno Ferodo',
    precio: 15,
    salePriceUsd: 13.5,
    stock: 50,
    minOrderQty: 5,
    category: 'Frenos / Pastillas');
const directoryItems = [
  SupplierDirectoryEntry(
      profile: directoryStore,
      purchased: true,
      categories: ['Frenos / Pastillas', 'Transmisión / Cadenas']),
  SupplierDirectoryEntry(
      profile: ImporterStoreProfile(
          id: 'other',
          businessName: 'Motoboxes',
          ciudad: 'Valencia',
          estado: 'Carabobo'),
      categories: ['Cauchos y ruedas / Cauchos'])
];

Future<SupplierDirectoryPage> directoryFixtureLoader(
        {required String query,
        required SupplierDirectoryFilter filter,
        required String? state,
        required String? category,
        required int offset}) async =>
    SupplierDirectoryPage(
        items: filter == SupplierDirectoryFilter.all
            ? directoryItems
            : directoryItems.take(1).toList(),
        total: filter == SupplierDirectoryFilter.all ? 2 : 1,
        states: const ['Carabobo', 'Distrito Capital'],
        categories: const ['Frenos / Pastillas']);

ImporterStoreCatalogSource directoryStoreSource({
  Future<List<PartModel>> Function(
          {required int limit,
          required int offset,
          required CatalogFilters filters})?
      fetchParts,
}) =>
    ImporterStoreCatalogSource(
        fetchProfile: (_) async => directoryStore,
        fetchCategories: (_) async =>
            ['Frenos / Pastillas', 'Transmisión / Cadenas'],
        fetchParts: fetchParts ??
            ({required limit, required offset, required filters}) async =>
                [directoryProduct]);

Future<void> pumpDirectory(WidgetTester tester,
    {double width = 390,
    double scale = 1,
    bool dark = false,
    bool reducedMotion = false,
    SupplierDirectoryLoader? loader,
    ValueChanged<String>? onOpenStore,
    bool store = false,
    ImporterStoreCatalogSource? source,
    Future<void> Function(BuildContext)? onChat}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? buildAppDarkTheme() : buildAppTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion),
          child: child!),
      home: store
          ? ImporterStoreProfileScreen(
              importerId: 'supplier',
              viewer: directoryViewer,
              catalogSource: source ?? directoryStoreSource(),
              onOpenSupplierChat: onChat)
          : SupplierDirectoryScreen(
              viewer: directoryViewer,
              loader: loader ?? directoryFixtureLoader,
              onOpenStore: onOpenStore)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Map<String, dynamic>? directoryRpcParams;

Future<void> revealDirectory(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
          of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
      .first;
  for (var step = 0; target.evaluate().isEmpty && step < 30; step++) {
    await tester.drag(scrollable, const Offset(0, -150));
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .3);
  await tester.pumpAndSettle();
}

Future<void> initializeDirectoryFixture() async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
      url: 'https://fixture.supabase.co',
      anonKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false, autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/aliado_supplier_directory')) {
          directoryRpcParams =
              Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          return http.Response(
              jsonEncode(
                  {'items': [], 'total': 0, 'states': [], 'categories': []}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
              request: request);
        }
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }));
}

void main() {
  setUpAll(initializeDirectoryFixture);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    CartService.instance.clear();
    directoryRpcParams = null;
  });

  test('directory request sends server filters and bounded pagination',
      () async {
    await SupplierDirectoryService.load(
        query: '  Ferodo ',
        filter: SupplierDirectoryFilter.purchased,
        state: 'Distrito Capital',
        category: 'Frenos / Pastillas',
        offset: 40);
    expect(directoryRpcParams, {
      'p_query': 'Ferodo',
      'p_filter': 'purchased',
      'p_estado': 'Distrito Capital',
      'p_category': 'Frenos / Pastillas',
      'p_limit': 40,
      'p_offset': 40
    });
  });

  for (final config in [
    (320.0, 1.0, false),
    (390.0, 1.6, false),
    (390.0, 1.0, true)
  ]) {
    testWidgets('directory and store fit mobile $config', (tester) async {
      String? opened;
      await pumpDirectory(tester,
          width: config.$1,
          scale: config.$2,
          dark: config.$3,
          onOpenStore: (id) => opened = id);
      await tester.pumpAndSettle();
      expect(find.text('Donde ya compraste'), findsOneWidget);
      expect(tester.getRect(find.byType(CustomScrollView).last).bottom,
          greaterThan(tester.getTopLeft(find.byType(AliadoBottomNav)).dy));
      await tester.scrollUntilVisible(find.text('Aún sin valoraciones'), 150,
          scrollable: find
              .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('Aún sin valoraciones'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text(directoryStore.displayName), -150,
          scrollable: find
              .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
          tester.element(find.text(directoryStore.displayName)),
          alignment: .35);
      await tester.pumpAndSettle();
      await tester.tap(find.text(directoryStore.displayName));
      expect(opened, 'supplier');
      expect(tester.takeException(), isNull);
      await pumpDirectory(tester,
          store: true, width: config.$1, scale: config.$2, dark: config.$3);
      await tester.pumpAndSettle();
      final toolbar = find.byType(AppBar);
      final storeTitle = find.descendant(
          of: toolbar, matching: find.text(directoryStore.displayName));
      final signature = find.descendant(
          of: toolbar, matching: find.text('B2B CONECTA'));
      expect(signature, findsOneWidget);
      expect(tester.getTopLeft(signature).dy,
          greaterThan(tester.getBottomLeft(storeTitle).dy));
      expect(tester.getBottomLeft(signature).dy,
          lessThan(tester.getBottomLeft(toolbar).dy));
      expect(find.byTooltip('Bolsa').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Compartir QR').hitTestable(), findsOneWidget);
      expect(find.text('Datos y ubicación'), findsOneWidget);
      expect(tester.getRect(find.byType(CustomScrollView)).bottom,
          greaterThan(tester.getTopLeft(find.byType(AliadoBottomNav)).dy));
      expect(find.text('RIF J-12345678'), findsNothing);
      await revealDirectory(
          tester, find.byKey(const Key('store-commercial-details')));
      await tester.tap(find.text('Datos y ubicación'));
      await tester.pumpAndSettle();
      await revealDirectory(tester, find.text('RIF J-12345678'));
      expect(find.text('RIF J-12345678'), findsOneWidget);
      await revealDirectory(tester, find.byType(AliadoProductCard));
      expect(find.text('Agregar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'search invalidates old results during debounce and ignores late responses',
      (tester) async {
    final old = Completer<SupplierDirectoryPage>();
    final queries = <String>[];
    await pumpDirectory(tester, loader: (
        {required query,
        required filter,
        required state,
        required category,
        required offset}) {
      queries.add(query);
      if (query.isEmpty) return old.future;
      return Future.value(
          SupplierDirectoryPage(items: [directoryItems[1]], total: 1));
    });
    await tester.enterText(find.byType(TextField), 'Motoboxes');
    await tester.pump();
    old.complete(SupplierDirectoryPage(items: [directoryItems[0]], total: 1));
    await tester.pump();
    expect(find.text(directoryStore.displayName), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(queries, ['', 'Motoboxes']);
    expect(find.text('Motoboxes'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Donde compraste'));
    await tester.pumpAndSettle();
    expect(queries.last, 'Motoboxes');
    expect(tester.takeException(), isNull);
  });

  testWidgets('error and empty state allow retry without technical details',
      (tester) async {
    var fail = true;
    await pumpDirectory(tester, loader: (
        {required query,
        required filter,
        required state,
        required category,
        required offset}) async {
      if (fail) throw StateError('private database details');
      return const SupplierDirectoryPage(items: [], total: 0);
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('private'), findsNothing);
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No encontramos proveedores con estos filtros.'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Donde compraste'));
    await tester.pumpAndSettle();
    expect(find.textContaining('compras confirmadas'), findsOneWidget);
  });

  testWidgets(
      'filters apply on server and pagination keeps all loaded suppliers',
      (tester) async {
    String? chosenState, chosenCategory;
    final offsets = <int>[];
    await pumpDirectory(tester, loader: (
        {required query,
        required filter,
        required state,
        required category,
        required offset}) async {
      offsets.add(offset);
      chosenState = state;
      chosenCategory = category;
      return SupplierDirectoryPage(
          items: [directoryItems[offset == 0 ? 0 : 1]],
          total: 2,
          states: const ['Carabobo'],
          categories: const ['Frenos / Pastillas']);
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver más proveedores'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Ver más proveedores')).bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(AliadoBottomNav)).dy));
    await tester.tap(find.text('Ver más proveedores'));
    await tester.pumpAndSettle();
    expect(offsets, [0, 1]);
    expect(find.text('Motoboxes'), findsOneWidget);
    if (find.byTooltip('Abrir búsqueda de proveedores').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Abrir búsqueda de proveedores'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Filtros de proveedores'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carabobo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frenos / Pastillas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(chosenState, 'Carabobo');
    expect(chosenCategory, 'Frenos / Pastillas');
    expect(offsets.last, 0);
  });

  testWidgets(
      'store search preserves owner and category and discards late results',
      (tester) async {
    final queries = <CatalogFilters>[];
    final old = Completer<List<PartModel>>();
    await pumpDirectory(tester, store: true, source: directoryStoreSource(
        fetchParts: ({required limit, required offset, required filters}) {
      queries.add(filters);
      return queries.length == 1 ? old.future : Future.value([]);
    }));
    await tester.enterText(
        find.byKey(const Key('store-product-search')), 'NGK');
    await tester.pump();
    old.complete([directoryProduct]);
    await tester.pump();
    expect(find.byType(AliadoProductCard), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(queries.last.ownerId, 'supplier');
    expect(queries.last.searchQuery, 'NGK');
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Frenos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Frenos'));
    await tester.pumpAndSettle();
    expect(queries.last.searchQuery, 'NGK');
    expect(queries.last.ownerId, 'supplier');
    expect(queries.last.category, 'Frenos / Pastillas');
    await revealDirectory(
        tester, find.text('No hay productos que coincidan con tu búsqueda.'));
    expect(find.text('No hay productos que coincidan con tu búsqueda.'),
        findsOneWidget);
  });

  testWidgets(
      'store quick add respects minimum, updates bag and opens supplier chat',
      (tester) async {
    var opened = 0;
    await pumpDirectory(tester, store: true, onChat: (_) async => opened++);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('store-supplier-chat')));
    await tester.tap(find.byKey(const Key('store-supplier-chat')));
    await tester.pumpAndSettle();
    expect(opened, 1);
    await tester.ensureVisible(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(CartService.instance.itemCount, 5);
    expect(find.byTooltip('Bolsa'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.byType(ImporterStoreProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'supplier navigation leaves both nested pages and opens the chosen module',
      (tester) async {
    var selected = -1;
    var shellRefreshes = 0;
    MainShellTabController.register((index) => selected = -100);
    MainShellTabController.registerAliadoTabSelection((index) {
      selected = index;
      shellRefreshes++;
    });
    addTearDown(MainShellTabController.unregister);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (directoryContext) => SupplierDirectoryScreen(
                            viewer: directoryViewer,
                            loader: directoryFixtureLoader,
                            onOpenStore: (id) => Navigator.of(directoryContext)
                                .push(MaterialPageRoute<void>(
                                    builder: (_) => ImporterStoreProfileScreen(
                                        importerId: id,
                                        viewer: directoryViewer,
                                        catalogSource: directoryStoreSource())))))),
                    child: const Text('Abrir proveedores'))))));
    await tester.tap(find.text('Abrir proveedores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(directoryStore.displayName));
    await tester.pumpAndSettle();
    expect(find.byType(AliadoBottomNav), findsOneWidget);
    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    expect(selected, AliadoShellTabs.pedidos);
    expect(shellRefreshes, 1);
    expect(find.byType(SupplierDirectoryScreen), findsNothing);
    expect(find.byType(ImporterStoreProfileScreen), findsNothing);
    expect(find.text('Abrir proveedores'), findsOneWidget);
  });

  testWidgets(
      'store rows align with different prices, and large text uses the full width',
      (tester) async {
    final other = directoryProduct.copyWith(
        id: 'other-product',
        nombre: 'Bujía NGK',
        precio: 3.2,
        salePriceUsd: 3.2,
        imagenUrl: 'https://fixture.test/spark.jpg');
    final first =
        directoryProduct.copyWith(imagenUrl: 'https://fixture.test/brakes.jpg');
    final source = directoryStoreSource(
        fetchParts: (
                {required limit, required offset, required filters}) async =>
            [first, other]);
    await pumpDirectory(tester, store: true, source: source);
    await tester.pumpAndSettle();
    await revealDirectory(tester, find.byType(AliadoProductCard));
    final cards = find.byType(AliadoProductCard);
    expect(tester.getSize(cards.first).height,
        closeTo(tester.getSize(cards.last).height, 1));
    expect(tester.getTopLeft(cards.first).dy,
        closeTo(tester.getTopLeft(cards.last).dy, 1));
    for (final image in tester.widgetList<Image>(
        find.descendant(of: cards, matching: find.byType(Image)))) {
      expect(image.fit, BoxFit.contain);
    }
    expect(tester.takeException(), isNull);
    await pumpDirectory(tester,
        store: true, source: source, width: 320, scale: 1.6);
    await tester.pumpAndSettle();
    await revealDirectory(tester, find.byType(AliadoProductCard));
    expect(tester.getSize(find.byType(AliadoProductCard).first).width,
        closeTo(288, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop store keeps its cards and gains catalog search',
      (tester) async {
    await pumpDirectory(tester, store: true, width: 1100);
    await tester.pumpAndSettle();
    expect(find.text('B2B CONECTA'), findsNothing);
    expect(find.byType(SupplierMobileNavigation), findsNothing);
    expect(find.byType(SupplierFilterChip), findsNothing);
    expect(find.byType(AliadoProductCard), findsNothing);
    expect(find.byKey(const Key('store-product-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'supplier search collapses with scroll, preserves query and reopens: reduced motion $reduced',
        (tester) async {
      await pumpDirectory(tester,
          reducedMotion: reduced,
          loader: (
                  {required query,
                  required filter,
                  required state,
                  required category,
                  required offset}) async =>
              SupplierDirectoryPage(
                  items: List.generate(
                      20,
                      (index) => SupplierDirectoryEntry(
                          profile: ImporterStoreProfile(
                              id: 'supplier-$index',
                              businessName: 'Proveedor $index'),
                          purchased: true)),
                  total: 20));
      await tester.pumpAndSettle();
      final nested =
          tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
      final header = find.byType(AppBar);
      final expandedHeight = tester.getSize(header).height;
      final bagPosition = tester.getRect(find.byTooltip('Bolsa'));
      final fade = find.byKey(const Key('supplier-search-fade'));
      expect(expandedHeight, closeTo(126, 1));
      expect(tester.widget<Opacity>(fade).opacity, 1);

      nested.outerController.jumpTo(14);
      await tester.pump();
      expect(
          tester.getSize(header).height, inExclusiveRange(56, expandedHeight));
      expect(tester.widget<Opacity>(fade).opacity,
          reduced ? 1 : inExclusiveRange(0, 1));
      nested.outerController.jumpTo(70);
      await tester.pumpAndSettle();
      expect(tester.getSize(header).height, closeTo(56, 1));
      expect(tester.widget<Opacity>(fade).opacity, 0);
      expect(find.text('Proveedores'), findsOneWidget);
      expect(find.byTooltip('Bolsa'), findsOneWidget);
      expect(tester.getRect(find.byTooltip('Bolsa')), bagPosition);
      final searchIcon = tester.widget<LucideIcon>(find.descendant(
          of: find.byTooltip('Abrir búsqueda de proveedores'),
          matching: find.byType(LucideIcon)));
      expect(searchIcon.glyph, LucideGlyph.search);
      expect(searchIcon.size, 21);
      expect(
          tester.getCenter(find.byTooltip('Abrir búsqueda de proveedores')).dx,
          lessThan(tester.getCenter(find.byTooltip('Bolsa')).dx));
      final purchasedFilter = find.widgetWithText(ChoiceChip, 'Donde compraste');
      final count = find.text('20 proveedores');
      final filterPosition = tester.getRect(purchasedFilter);
      final countPosition = tester.getRect(count);
      expect(filterPosition.top, greaterThan(tester.getRect(header).bottom));

      final supplierList = find.byType(CustomScrollView);
      await tester.drag(supplierList, const Offset(0, -550));
      await tester.pumpAndSettle();
      expect(nested.innerController.offset, greaterThan(300));
      expect(tester.getRect(purchasedFilter), filterPosition);
      expect(tester.getRect(count), countPosition);
      expect(purchasedFilter.hitTestable(), findsOneWidget);

      await tester.tap(find.byTooltip('Abrir búsqueda de proveedores'));
      await tester.pumpAndSettle();
      expect(tester.getSize(header).height, closeTo(expandedHeight, 1));
      expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue);
      await tester.enterText(find.byType(TextField), 'Ferodo');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final list = find
          .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable))
          .first;
      await tester.drag(list, const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(fade).opacity, 0);
      expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isFalse);
      await tester.tap(find.byTooltip('Abrir búsqueda de proveedores'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Ferodo');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'short supplier lists collapse without viewport feedback and reset when filtering',
      (tester) async {
    await pumpDirectory(tester);
    await tester.pumpAndSettle();
    final nested =
        tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
    nested.outerController.jumpTo(35);
    await tester.pumpAndSettle();
    expect(nested.outerController.offset, closeTo(35, 1));
    expect(tester.getSize(find.byType(AppBar)).height, closeTo(91, 1));
    nested.outerController.jumpTo(70);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Donde compraste'));
    await tester.pumpAndSettle();
    expect(nested.outerController.offset, 0);
    expect(tester.getSize(find.byType(AppBar)).height, closeTo(126, 1));
    expect(tester.takeException(), isNull);
  });
}
