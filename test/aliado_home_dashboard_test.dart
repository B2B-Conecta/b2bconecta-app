import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/config/terms_config.dart';
import 'package:motolink_pro_app/core/layout/aliado_bottom_nav.dart';
import 'package:motolink_pro_app/core/notifications/notification_deep_link.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';
import 'package:motolink_pro_app/features/dashboard/aliado_home_dashboard.dart';
import 'package:motolink_pro_app/features/dashboard/aliado_home_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_overview.dart';

void main() {
  tearDown(MainShellTabController.unregister);
  testWidgets(
      'notification links retain catalog, orders and profile destinations',
      (tester) async {
    int? tab;
    MainShellTabController.register((index) => tab = index);
    MainShellTabController.registerB2BNavigation(
        home: AliadoShellTabs.inicio,
        pedidos: AliadoShellTabs.pedidos,
        reputation: AliadoShellTabs.perfil,
        profile: AliadoShellTabs.perfil);
    navigateFromNotificationPayload(
        homeRole: AppHomeRole.aliado, type: 'catalogo');
    expect(tab, AliadoShellTabs.catalogo);
    navigateFromNotificationPayload(
        homeRole: AppHomeRole.aliado, type: 'mensaje', relatedId: 'order-id');
    expect(tab, AliadoShellTabs.pedidos);
    expect(
        MainShellTabController.peekPendingNotificationRelatedId(), 'order-id');
    expect(MainShellTabController.consumePendingOpenOrderChat(), isTrue);
    navigateFromNotificationPayload(homeRole: AppHomeRole.aliado, type: 'kyc');
    expect(tab, AliadoShellTabs.perfil);
    await tester.pump();
    await tester.pump();
  });
  const product = PartModel(
      id: 'oil',
      nombre: 'Aceite 4T 20W50',
      precio: 12,
      salePriceUsd: 10,
      ownerId: 'supplier',
      ownerBusinessName: 'Proveedor de prueba',
      stock: 40);
  final profile = ProfileModel(
      id: 'retailer',
      role: 'aliado',
      businessName: 'Taller',
      rif: 'J-123',
      phone: '04241234567',
      estado: 'Miranda',
      ciudad: 'Caracas',
      direccion: 'Dirección del taller',
      fiscalMapsUrl: 'https://maps.google.com',
      accountAccessStatus: 'active',
      kycStatus: 'aprobado',
      termsAcceptedAt: DateTime(2026),
      termsVersion: TermsConfig.currentVersion,
      ratingAsPayerAvgRolling100: 4.5,
      ratingAsPayerCountRolling100: 8);

  for (final (width, scale) in [(320.0, 1.0), (390.0, 1.6)]) {
    testWidgets('mobile home and raised nav work at $width with scale $scale',
        (tester) async {
      tester.view.physicalSize = Size(width, 830);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? tab;
      var messagesOpened = 0;
      var notificationsOpened = 0;
      MainShellTabController.register((index) => tab = index);
      final branded = product.copyWith(customFields: const {
        'marca': 'Prueba',
        '_aliado_visible_keys': ['marca'],
      });
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: AliadoHomeDashboard(
              profile: profile,
              onMessagesTap: () => messagesOpened++,
              onNotificationTap: () => notificationsOpened++,
              unreadNotifications: 12,
              unreadMessages: 11,
              loader: () async => AliadoHomeData(
                  buyAgain: [product],
                  bestSellers: [product],
                  newArrivals: [branded],
                  activeOrders: 2,
                  suppliers: const [
                    ImporterOption(
                        id: 'supplier', businessName: 'Proveedor de prueba'),
                  ])),
          bottomNavigationBar: AliadoBottomNav(
              currentIndex: AliadoShellTabs.inicio,
              onTap: (index) => tab = index),
        ),
      ));
      await tester.pumpAndSettle();
      final identity = find.text(profile.businessName!);
      final identityElement = tester.element(identity);
      expect(find.text('Para tu negocio'), findsNothing);
      final bcv = find.byKey(const ValueKey('home-bcv'));
      final cart = find.byTooltip('Bolsa');
      expect(bcv, findsOneWidget);
      expect(tester.getCenter(bcv).dx - tester.getCenter(cart).dx, 44);
      expect(find.byTooltip('Abrir búsqueda'), findsNothing);
      expect(find.byTooltip('Bandeja'), findsOneWidget);
      await tester.tap(find.byTooltip('Bandeja'));
      await tester.pumpAndSettle();
      expect(find.text('11 sin leer'), findsOneWidget);
      expect(find.text('12 sin leer'), findsOneWidget);
      await tester.tap(find.text('Mensajes'));
      await tester.pumpAndSettle();
      expect(messagesOpened, 1);
      await tester.tap(find.byTooltip('Filtros del catálogo'));
      expect(tab, AliadoShellTabs.catalogo);
      expect(MainShellTabController.consumeAliadoCatalogRequest()!.openFilters,
          isTrue);
      await tester.scrollUntilVisible(find.text('Prueba'), 150,
          scrollable: find
              .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable))
              .first);
      await Scrollable.ensureVisible(tester.element(find.text('Prueba')),
          alignment: .4);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prueba'));
      expect(
          MainShellTabController.consumeAliadoCatalogRequest()!
              .filters
              .brandField
              ?.value,
          'Prueba');
      await tester.scrollUntilVisible(find.text('Tus proveedores'), 150,
          scrollable: find
              .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable))
              .first);
      final suppliersHeading = find.text('Tus proveedores');
      final storeLink = find.widgetWithText(TextButton, 'Ver tiendas');
      await Scrollable.ensureVisible(tester.element(storeLink), alignment: .45);
      await tester.pumpAndSettle();
      expect(tester.getCenter(storeLink).dy,
          closeTo(tester.getCenter(suppliersHeading).dy, 1));
      await tester.tap(storeLink);
      await tester.pumpAndSettle();
        expect(find.text('Proveedores'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bolsa'), findsOneWidget);
      expect(tester.getCenter(bcv).dx - tester.getCenter(cart).dx, 44);
      expect(tester.element(identity), same(identityElement));
      await tester.tap(find.byTooltip('Bandeja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notificaciones'));
      await tester.pumpAndSettle();
      expect(notificationsOpened, 1);
      await tester.tap(find.byTooltip('Abrir búsqueda'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'caucho');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
          MainShellTabController.consumeAliadoCatalogRequest()!
              .filters
              .searchQuery,
          'caucho');
      await tester.tap(find.text('Favoritos'));
      expect(tab, AliadoShellTabs.favoritos);
      expect(tester.takeException(), isNull);
    });
  }

  for (final count in [1, 2]) {
    testWidgets('home shows only $count real promotions', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AliadoHomeDashboard(
          profile: profile,
          loader: () async => AliadoHomeData(promotions: [
            for (var i = 0; i < count; i++)
              PromoCampaignModel(
                id: '$i',
                internalTitle: 'Promoción $i',
                campaignType: PromoCampaignModel.typeBanner,
                imageStoragePath: 'promo-$i.png',
                imagePublicUrl: 'https://fixture.invalid/promo-$i.png',
                actionType: PromoCampaignModel.actionOpenStore,
                startsAt: DateTime(2026),
                endsAt: DateTime(2027),
                priority: 0,
                isActive: true,
              ),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Para tu negocio'), findsOneWidget);
      expect(find.text('Abastece tu negocio'), findsNothing);
      expect(find.text('Ver seguimiento'), findsNothing);
      expect(find.byType(PageView), count == 1 ? findsNothing : findsOneWidget);
      if (count > 1) {
        Finder banner(int index) => find.byWidgetPredicate((widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url.endsWith('/promo-$index.png'));
        final width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final leftInset = tester.getRect(banner(0)).left;
        expect(leftInset, tester.getTopLeft(find.text('Para tu negocio')).dx);
        expect(tester.getRect(banner(1)).right, greaterThan(width));
        await tester.tap(find.byTooltip('Tarjeta 2 de 2'));
        await tester.pumpAndSettle();
        expect(width - tester.getRect(banner(1)).right, closeTo(leftInset, .5));
      }
      expect(find.byTooltip('Tarjeta 1 de 2'),
          count == 1 ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile product rails align their ends and center middle cards',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final products = [
      for (var i = 1; i <= 3; i++)
        product.copyWith(id: 'product-$i', nombre: 'Repuesto $i'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: AliadoHomeDashboard(
        profile: profile,
        loader: () async =>
            AliadoHomeData(bestSellers: products, newArrivals: products),
      ),
    ));
    await tester.pumpAndSettle();
    final rails = find.byWidgetPredicate((widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal);
    expect(rails, findsNWidgets(2));
    for (final (index, width) in [318.56, 275.12].indexed) {
      final rail = rails.at(index);
      await Scrollable.ensureVisible(tester.element(rail), alignment: .4);
      final cards = find.descendant(
        of: rail,
        matching: find.byWidgetPredicate((widget) =>
            widget is SizedBox && ((widget.width ?? 0) - width).abs() < .1),
      );
      expect(cards, findsNWidgets(3));
      expect(tester.getRect(cards.first).left, closeTo(14, .5));
      final stride = width + 8;
      await tester.timedDrag(
          rail, Offset(-stride * .7, 0), const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      // The scroll spring settles within one logical pixel.
      expect(tester.getCenter(cards.at(1)).dx, closeTo(195, 1));
      await tester.drag(rail, const Offset(-390, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(cards.last).right, closeTo(376, .5));
    }
  });

  testWidgets('Más vendidos distinguishes quick add from product details',
      (tester) async {
    final cart = CartService.instance;
    cart.clear();
    addTearDown(cart.clear);
    final variant = product.copyWith(
        id: 'variant', nombre: 'Bujía con opciones', parentSku: 'family');
    final unavailable = product.copyWith(
        id: 'unavailable', nombre: 'Repuesto agotado', stock: 0);

    await tester.pumpWidget(MaterialApp(
      home: AliadoHomeDashboard(
        profile: profile,
        loader: () async =>
            AliadoHomeData(bestSellers: [product, variant, unavailable]),
      ),
    ));
    await tester.pumpAndSettle();
    final rail = find.byWidgetPredicate((widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal);
    expect(tester.getRect(rail).left, 0);
    expect(tester.getRect(rail).right,
        tester.view.physicalSize.width / tester.view.devicePixelRatio);
    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();

    String iconAsset(Finder action) {
      final icon = tester.widget<SvgPicture>(
        find.descendant(of: action, matching: find.byType(SvgPicture)),
      );
      return (icon.bytesLoader as SvgAssetLoader).assetName;
    }

    final quickAdd = find.byTooltip('Agregar ${product.nombre}').hitTestable();
    final options =
        find.byTooltip('Ver opciones ${variant.nombre}').hitTestable();
    final details =
        find.byTooltip('Ver detalle ${unavailable.nombre}').hitTestable();
    expect(iconAsset(quickAdd), 'assets/handbag_plus/light-normal.svg');
    expect(iconAsset(options), 'assets/angulo/angulo-pequeno-derecho.svg');
    expect(iconAsset(details), 'assets/angulo/angulo-pequeno-derecho.svg');

    await tester.tap(quickAdd);
    await tester.pumpAndSettle();
    expect(cart.lines.single.quantity, product.minOrderQtyEffective);
    final inCart =
        find.byTooltip('${product.nombre} ya está en el carrito').hitTestable();
    expect(
        iconAsset(inCart), 'assets/handbag_solid/light-selected-disabled.svg');
    final disabledAction = find.descendant(
      of: inCart,
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(disabledAction).onPressed, isNull);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    final labeled = find.ancestor(
      of: find.text('En carrito'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(
        iconAsset(labeled), 'assets/handbag_solid/light-selected-disabled.svg');
    expect(tester.widget<FilledButton>(labeled).onPressed, isNull);

    cart.removeProduct(product.id);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();
    expect(iconAsset(quickAdd), 'assets/handbag_plus/light-normal.svg');
  });

  test('category shortcuts group real values and prioritize common supplies',
      () {
    final groups = prioritizeHomeCategories(catalogCategoryFamilies([
      'Accesorios',
      'Frenos',
      'Freno',
      'Cauchos',
      'Aceite',
      'Transmisión',
      'Eléctrico e iluminación / Baterías',
    ]));
    expect(groups.take(4).map((g) => g.label), [
      'Cauchos y ruedas',
      'Frenos',
      'Transmisión',
      'Eléctrico e iluminación'
    ]);
    expect(groups[1].values, containsAll(['Frenos', 'Freno']));
  });

  testWidgets(
      'navigation preserves catalog filters and consumes them only once',
      (tester) async {
    int? tab;
    MainShellTabController.register((index) => tab = index);
    MainShellTabController.navigateToAliadoCatalog(
        filters: const CatalogFilters(
            searchQuery: 'aceite', categoryAnyOf: ['Aceite', 'Aceites']));
    expect(tab, AliadoShellTabs.catalogo);
    final request = MainShellTabController.consumeAliadoCatalogRequest()!;
    expect(request.filters.searchQuery, 'aceite');
    expect(request.filters.categoryAnyOf, ['Aceite', 'Aceites']);
    expect(MainShellTabController.consumeAliadoCatalogRequest(), isNull);
    await tester.pump();
  });

  testWidgets(
      'retailer reputation opens from profile without changing supplier navigation',
      (tester) async {
    var opened = false;
    int? tab;
    MainShellTabController.register((i) => tab = i);
    MainShellTabController.registerB2BNavigation(
        home: 0,
        pedidos: 1,
        reputation: 4,
        profile: 4,
        onReputation: () => opened = true);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ProfileOverview(
                    profile: profile,
                    onEdit: () {},
                    onSignOut: () {},
                    accountActionsInShell: true)))));
    await tester.pumpAndSettle();
    expect(find.text('4,5 / 5 · 8 valoraciones'), findsOneWidget);
    await tester.tap(find.text('Mi reputación'));
    expect(opened, isTrue);
    expect(tab, isNull);
    MainShellTabController.registerB2BNavigation(
        home: 0, pedidos: 2, reputation: 3, profile: 4);
    MainShellTabController.navigateToReputationTab();
    expect(tab, 3);
    await tester.pump();
  });

  for (final width in [320.0, 390.0, 1300.0]) {
    testWidgets('Inicio adapts product sections and search at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? tab;
      MainShellTabController.register((i) => tab = i);
      await tester.pumpWidget(MaterialApp(
          home: AliadoHomeDashboard(
              profile: profile,
              embedInDesktopShell: true,
              loader: () async => const AliadoHomeData(buyAgain: [
                    product
                  ], bestSellers: [
                    product
                  ], categories: [
                    AliadoCatalogCategoryGroup(
                        label: 'Aceites', values: ['aceite', 'Aceites'])
                  ]))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Compra de nuevo'), findsOneWidget);
      expect(find.text('12.00 REF'), findsWidgets);
      expect(find.text('10.00 USD'), findsWidgets);
      expect(find.bySemanticsLabel('Explora el catálogo'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.bySemanticsLabel('Explora el catálogo'));
      await tester.pump();
      expect(tab, AliadoShellTabs.catalogo);
      expect(
          MainShellTabController.consumeAliadoCatalogRequest()!
              .filters
              .searchQuery,
          isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Aceites'));
      await tester.tap(find.text('Aceites'));
      await tester.pump();
      expect(
          MainShellTabController.consumeAliadoCatalogRequest()!
              .filters
              .categoryAnyOf,
          ['aceite', 'Aceites']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Cascos opens its own catalog from Accesorios', (tester) async {
    MainShellTabController.register((_) {});
    await tester.pumpWidget(MaterialApp(
      home: AliadoHomeDashboard(
        profile: profile,
        embedInDesktopShell: true,
        loader: () async => AliadoHomeData(
          categories: catalogCategoryFamilies([
            'Accesorios / Cascos',
            'Accesorios / Visores',
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver todas'));
    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ExpansionTile, 'Accesorios'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cascos'));
    await tester.pumpAndSettle();
    final request = MainShellTabController.consumeAliadoCatalogRequest()!;
    expect(request.filters.category, 'Accesorios / Cascos');
    expect(request.filters.categoryAnyOf, ['Accesorios / Cascos']);
  });

  testWidgets(
      'first purchase has truthful empty state instead of invented history',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AliadoHomeDashboard(
            profile: profile,
            embedInDesktopShell: true,
            loader: () async => const AliadoHomeData())));
    await tester.pumpAndSettle();
    expect(find.text('Tu próxima compra comienza aquí'), findsOneWidget);
    expect(find.text('Compra de nuevo'), findsNothing);
    expect(find.text('Más vendidos'), findsNothing);
  });

  testWidgets(
      'carousel controls update when the desktop window becomes narrower',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: AliadoHomeDashboard(
            profile: profile,
            embedInDesktopShell: true,
            loader: () async => AliadoHomeData(buyAgain: [
                  for (var i = 0; i < 5; i++)
                    PartModel(
                        id: 'sku$i',
                        nombre: 'Repuesto $i',
                        precio: 12,
                        stock: 40),
                ]))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Más productos'), findsNothing);
    tester.view.physicalSize = const Size(1200, 1100);
    await tester.pumpAndSettle();
    final next = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Más productos');
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton &&
                widget.tooltip == 'Productos anteriores'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets('desktop home aligns purchase buttons at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const standard = PartModel(
          id: 'plain-card',
          ownerId: 'supplier',
          nombre: 'Bujía',
          precio: 12,
          stock: 40);
      const offer = PartModel(
          id: 'offer-card',
          ownerId: 'supplier',
          ownerBusinessName: 'Distribuidora de repuestos',
          nombre: 'Pastillas de freno delanteras para motocicletas',
          parentSku: 'BRAKE',
          precio: 12,
          salePriceUsd: 9,
          stock: 40);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: AliadoHomeDashboard(
              profile: profile,
              embedInDesktopShell: true,
              loader: () async =>
                  const AliadoHomeData(newArrivals: [standard, offer]))));
      await tester.pumpAndSettle();
      final standardButton = tester.getRect(find.byTooltip('Agregar Bujía'));
      final offerButton =
          tester.getRect(find.byTooltip('Ver opciones ${offer.nombre}'));
      expect(standardButton.top, closeTo(offerButton.top, 0.5));
      expect(standardButton.height, closeTo(offerButton.height, 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  for (final section in ['buyAgain', 'newArrivals', 'bestSellers']) {
    for (final size in [(320.0, 1.0), (390.0, 1.0), (320.0, 1.6)]) {
      testWidgets(
          'home keeps discount inline and minimum beside price: $section $size',
          (tester) async {
        tester.view.physicalSize = Size(size.$1, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const item = PartModel(
            id: 'minimum-layout',
            nombre: 'Kit embrague completo 125 cc',
            ownerBusinessName: 'Repuestos Delta Caracas C.A.',
            precio: 45,
            salePriceUsd: 41.5,
            stock: 100,
            minOrderQty: 5);
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(size.$2)),
                child: child!),
            home: AliadoHomeDashboard(
                profile: profile,
                loader: () async => AliadoHomeData(
                      buyAgain: section == 'buyAgain' ? [item] : const [],
                      newArrivals: section == 'newArrivals' ? [item] : const [],
                      bestSellers: section == 'bestSellers' ? [item] : const [],
                    ))));
        await tester.pumpAndSettle();
        final price = tester.getRect(find.text('41.50 USD'));
        final discount = tester.getRect(find.text('-8%'));
        final minimum = tester.getRect(find.text('Mín.\n5 uds'));
        expect(discount.left, greaterThan(price.right));
        expect(discount.center.dy, closeTo(price.center.dy, .5));
        expect(minimum.left, greaterThan(discount.right));
        final divider = tester.getRect(find.byType(VerticalDivider));
        expect(divider.left, greaterThanOrEqualTo(discount.right));
        expect(divider.right, lessThanOrEqualTo(minimum.left));
        expect(find.text('45.00 REF'), findsOneWidget);
        expect(find.text('Mín. 5 uds'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [320.0, 390.0, 540.0]) {
    testWidgets(
        'home cards align heights with prices beside larger photos at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const plain = PartModel(
          id: 'plain',
          nombre: 'Bujía NGK 125',
          precio: 3.2,
          stock: 100,
          minOrderQty: 20,
          ownerBusinessName: 'Proveedor');
      const promo = PartModel(
          id: 'promo',
          nombre: 'Filtro Ferodo',
          precio: 15,
          stock: 100,
          salePriceUsd: 13.5,
          minOrderQty: 10,
          ownerBusinessName: 'Proveedor');
      await tester.pumpWidget(MaterialApp(
          home: AliadoHomeDashboard(
              profile: profile,
              loader: () async =>
                  const AliadoHomeData(newArrivals: [plain, promo]))));
      await tester.pumpAndSettle();
      final tileWidth = width == 320
          ? 272.0
          : width == 390
              ? 275.12
              : 320.0;
      Rect card(String name) => tester.getRect(find.ancestor(
          of: find.text(name),
          matching: find.byWidgetPredicate((widget) =>
              widget is SizedBox &&
              ((widget.width ?? 0) - tileWidth).abs() < .1)));
      final plainCard = card(plain.nombre);
      final promoCard = card(promo.nombre);
      expect(plainCard.width, tileWidth);
      expect(plainCard.height, closeTo(promoCard.height, .1));
      expect(promoCard.height, lessThan(180));
      expect(tester.getRect(find.text('3.20 REF')).left,
          greaterThan(plainCard.left + 90));
      expect(tester.getRect(find.text('3.20 REF')).left,
          closeTo(tester.getRect(find.text(plain.nombre)).left, .1));
      expect(tester.getRect(find.text('Mín.\n20 uds')).right,
          closeTo(plainCard.right - 8, .1));
      expect(tester.getRect(find.text('Mín.\n10 uds')).right,
          closeTo(promoCard.right - 8, .1));
      final price = tester.getRect(find.text('13.50 USD'));
      final discount = tester.getRect(find.text('-10%'));
      expect(discount.left, greaterThan(price.right));
      expect(discount.center.dy, closeTo(price.center.dy, .5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('partial failure keeps available sections and offers retry',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        home: AliadoHomeDashboard(
            profile: profile,
            embedInDesktopShell: true,
            loader: () async {
              attempts++;
              return const AliadoHomeData(errors: [
                'tus compras y los más vendidos'
              ], categories: [
                AliadoCatalogCategoryGroup(label: 'Aceites', values: ['Aceite'])
              ]);
            })));
    await tester.pumpAndSettle();
    expect(find.text('Aceites'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Tu próxima compra comienza aquí'), findsNothing);
  });
}
