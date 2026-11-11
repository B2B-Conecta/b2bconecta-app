import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

import '../../app/main_shell_tab.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/ios_chrome.dart';
import '../../core/data/supabase_service.dart';
import '../../core/widgets/bcv_rate_badge.dart';
import '../cart/cart_screen.dart';
import '../cart/cart_service.dart';
import '../cart/cart_product_actions.dart';
import '../cart/catalog_cart_bar.dart';
import '../catalog/aliado_catalog_categories.dart';
import '../catalog/aliado_product_card.dart';
import '../catalog/aliado_promo_campaign_widgets.dart';
import '../catalog/catalog_category_icon.dart';
import '../catalog/catalog_product_price_display.dart';
import '../catalog/catalog_service.dart';
import '../catalog/catalog_filters.dart';
import '../catalog/catalog_taxonomy.dart';
import '../catalog/catalog_route_lock.dart';
import '../catalog/importer_store_profile_screen.dart';
import '../catalog/part_model.dart';
import '../catalog/product_detail_screen.dart';
import '../catalog/promo_campaign_model.dart';
import '../catalog/recent_product_views.dart';
import '../catalog/store_supplier_chat.dart';
import '../inventory/product_custom_fields.dart';
import '../profile/profile_model.dart';
import 'aliado_home_service.dart';
import 'aliado_home_header.dart';

part 'aliado_home_mobile.dart';

/// Descubrimiento y recompra. El catálogo conserva búsqueda y filtros completos.
class AliadoHomeDashboard extends StatefulWidget {
  const AliadoHomeDashboard(
      {super.key,
      required this.profile,
      this.embedInDesktopShell = false,
      this.isActiveTab = true,
      this.onNotificationTap,
      this.onMessagesTap,
      this.unreadNotifications = 0,
      this.unreadMessages = 0,
      this.loader});
  final ProfileModel profile;
  final bool embedInDesktopShell;
  final bool isActiveTab;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMessagesTap;
  final int unreadNotifications;
  final int unreadMessages;
  final Future<AliadoHomeData> Function()? loader;

  @override
  State<AliadoHomeDashboard> createState() => _AliadoHomeDashboardState();
}

class _AliadoHomeDashboardState extends State<AliadoHomeDashboard> {
  final _search = TextEditingController();
  late Future<AliadoHomeData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<AliadoHomeData> _load() => (widget.loader ?? AliadoHomeService.load)();

  @override
  void didUpdateWidget(covariant AliadoHomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        (!widget.embedInDesktopShell &&
            widget.isActiveTab &&
            !oldWidget.isActiveTab)) {
      _data = _load();
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _data = next;
    });
    // FutureBuilder muestra el error y ofrece reintentar sin perder el buscador.
    try {
      await next;
    } catch (_) {}
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _catalog([CatalogFilters filters = CatalogFilters.empty]) =>
      MainShellTabController.navigateToAliadoCatalog(filters: filters);

  void _searchCatalog() =>
      _catalog(CatalogFilters(searchQuery: _search.text.trim()));

  void _cart() => Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => CartScreen(profile: widget.profile, liveTasaBcv: null)));

  void _promotion(PromoCampaignModel campaign) =>
      MainShellTabController.navigateToAliadoCatalog(campaign: campaign);

  void _openCategory(AliadoCatalogCategoryGroup group) => _catalog(
      CatalogFilters(category: group.label, categoryAnyOf: group.values));

  void _categories(AliadoHomeData data) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
              child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .65,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        const Expanded(
                            child: Text('Categorías',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700))),
                        IconButton(
                            tooltip: 'Cerrar categorías',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const LucideIcon(LucideGlyph.close)),
                      ])),
                  Expanded(
                      child: ListView(children: [
                    for (final group in data.categories)
                      if (group.children.isEmpty)
                        ListTile(
                          leading: CatalogCategoryIcon(
                            art: CatalogCategoryArt.forLabel(group.label),
                            size: 24,
                          ),
                          title: Text(catalogCategoryDisplayLabel(group.label)),
                          trailing: const _HomeAngle(),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openCategory(group);
                          },
                        )
                      else
                        ExpansionTile(
                          leading: CatalogCategoryIcon(
                            art: CatalogCategoryArt.forLabel(group.label),
                            size: 24,
                          ),
                          title: Text(catalogCategoryDisplayLabel(group.label)),
                          children: [
                            for (final option in [group, ...group.children])
                              ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                leading: option.label ==
                                        'Lubricantes y mantenimiento / Aceites'
                                    ? const CatalogCategoryIcon(
                                        art: CatalogCategoryArt.oil, size: 20)
                                    : null,
                                title: Text(identical(option, group)
                                    ? 'Ver todo en ${catalogCategoryDisplayLabel(group.label)}'
                                    : categoryLeaf(option.label)),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _openCategory(option);
                                },
                              ),
                          ],
                        ),
                  ])),
                ]),
          )));

  @override
  Widget build(BuildContext context) {
    AppColors.brightness = Theme.of(context).brightness;
    if (!widget.embedInDesktopShell) return _mobile();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        Expanded(
            child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<AliadoHomeData>(
                    future: _data,
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      return CustomScrollView(
                          key: const PageStorageKey('aliado-inicio'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                                padding: EdgeInsets.fromLTRB(16,
                                    widget.embedInDesktopShell ? 0 : 18, 16, 0),
                                sliver: SliverToBoxAdapter(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(
                                                      '¿Qué necesita tu negocio?',
                                                      style: TextStyle(
                                                          fontSize: 22,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          height: 1.2)),
                                                  SizedBox(height: 6),
                                                  Text(
                                                      'Encuentra repuestos y repón lo que más vendes.'),
                                                ])),
                                            IconButton(
                                                tooltip: 'Actualizar Inicio',
                                                onPressed: _refresh,
                                                icon: const LucideIcon(
                                                    LucideGlyph.refreshCw)),
                                          ]),
                                      const SizedBox(height: 16),
                                      TextField(
                                          controller: _search,
                                          onSubmitted: (_) => _searchCatalog(),
                                          textInputAction:
                                              TextInputAction.search,
                                          decoration: InputDecoration(
                                              hintText:
                                                  'Repuesto, marca o código…',
                                              prefixIcon: const LucideIcon(
                                                  LucideGlyph.search),
                                              filled: true,
                                              fillColor: AppColors.fieldFill,
                                              suffixIcon: IconButton(
                                                  tooltip:
                                                      'Buscar en el catálogo',
                                                  onPressed: _searchCatalog,
                                                  icon: const _HomeAngle()),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                      color: AppColors
                                                          .borderSubtle)),
                                              enabledBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                      color: AppColors
                                                          .borderSubtle)))),
                                    ]))),
                            if (snapshot.connectionState !=
                                ConnectionState.done)
                              const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                      child: CircularProgressIndicator())),
                            if (snapshot.hasError ||
                                (data?.errors.isNotEmpty ?? false))
                              SliverPadding(
                                  padding: const EdgeInsets.all(16),
                                  sliver: SliverToBoxAdapter(
                                      child: Wrap(
                                          spacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                        Text(snapshot.hasError
                                            ? 'No pudimos cargar Inicio.'
                                            : 'No pudimos cargar ${data!.errors.join(', ')}.'),
                                        TextButton(
                                            onPressed: _refresh,
                                            child: const Text('Reintentar')),
                                      ]))),
                            if (data != null) ...[
                              if (data.promotions.isNotEmpty)
                                SliverPadding(
                                    padding: const EdgeInsets.only(top: 16),
                                    sliver: SliverToBoxAdapter(
                                        child: AliadoPromoBannerCarousel(
                                            campaigns: data.promotions,
                                            compact: widget.embedInDesktopShell,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            onPromoCampaignSelected: _promotion,
                                            onViewAll: () =>
                                                showAliadoActivePromotionsSheet(
                                                    context: context,
                                                    campaigns: data.promotions,
                                                    onPromoCampaignSelected:
                                                        _promotion)))),
                              if (data.buyAgain.isNotEmpty)
                                _products(
                                    'Compra de nuevo',
                                    'Tus compras, con precio y stock actuales.',
                                    data.buyAgain,
                                    action: 'Mis pedidos',
                                    onAction: MainShellTabController
                                        .navigateToPedidosTab)
                              else if (data.errors.isEmpty)
                                SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 22, 16, 0),
                                    sliver: SliverToBoxAdapter(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          const Text(
                                              'Tu próxima compra comienza aquí',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 6),
                                          const Text(
                                              'Explora el catálogo. Aquí podrás volver a comprar tus repuestos.'),
                                          TextButton.icon(
                                              onPressed: _catalog,
                                              icon: const _HomeAngle(size: 18),
                                              label: const Text(
                                                  'Explorar catálogo')),
                                        ]))),
                              if (data.categories.isNotEmpty)
                                SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 24, 16, 0),
                                    sliver: SliverToBoxAdapter(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                          _heading(
                                              'Explora por categoría',
                                              'Ver todas',
                                              () => _categories(data)),
                                          const SizedBox(height: 10),
                                          LayoutBuilder(
                                              builder: (context, constraints) {
                                            final count =
                                                MediaQuery.textScalerOf(context)
                                                            .scale(14) >
                                                        19
                                                    ? 2
                                                    : 4;
                                            final width =
                                                (constraints.maxWidth -
                                                        (count - 1) * 8) /
                                                    count;
                                            return Wrap(
                                                spacing: 8,
                                                runSpacing: 10,
                                                children: [
                                                  for (final group in data
                                                      .categories
                                                      .take(4))
                                                    SizedBox(
                                                        width: width,
                                                        child: _CategoryShortcut(
                                                            label: group.label,
                                                            onTap: () =>
                                                                _openCategory(
                                                                    group))),
                                                ]);
                                          }),
                                        ]))),
                              if (data.bestSellers.isNotEmpty)
                                _products(
                                    'Más vendidos',
                                    'Pedidos entregados en los últimos 30 días.',
                                    data.bestSellers)
                              else if (data.errors.isEmpty)
                                const SliverPadding(
                                    padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                                    sliver: SliverToBoxAdapter(
                                        child: Text(
                                            'Los más vendidos aparecerán cuando haya entregas recientes.'))),
                              SliverPadding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 24, 16, 24),
                                  sliver: SliverToBoxAdapter(
                                      child: Align(
                                          alignment: Alignment.center,
                                          child: OutlinedButton.icon(
                                              onPressed: _catalog,
                                              icon: const LucideIcon(
                                                  LucideGlyph.grid,
                                                  size: 18),
                                              label: const Text(
                                                  'Explorar todo el catálogo'))))),
                            ],
                          ]);
                    }))),
        CatalogCartBar(onOpen: _cart)
      ]),
    );
  }

  Widget _heading(String title, String action, VoidCallback onAction) =>
      Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700))),
        TextButton(onPressed: onAction, child: Text(action)),
      ]);

  Widget _products(String title, String subtitle, List<PartModel> products,
          {String? action, VoidCallback? onAction}) =>
      SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          sliver: SliverToBoxAdapter(
              child: _HomeProductRail(
                  title: title,
                  subtitle: subtitle,
                  action: action,
                  onAction: onAction,
                  products: products,
                  profile: widget.profile)));
}

class _HomeProductRail extends StatefulWidget {
  const _HomeProductRail(
      {required this.title,
      required this.subtitle,
      this.action,
      this.onAction,
      required this.products,
      required this.profile});
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;
  final List<PartModel> products;
  final ProfileModel profile;
  @override
  State<_HomeProductRail> createState() => _HomeProductRailState();
}

class _HomeProductRailState extends State<_HomeProductRail> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double direction) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _scroll.animateTo(
        (_scroll.offset + direction * position.viewportDimension)
            .clamp(0.0, position.maxScrollExtent),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final logicalWidth =
            (constraints.maxWidth + 32) / (scale < 1 ? 1 : scale);
        final columns = logicalWidth >= 1250
            ? 5
            : logicalWidth >= 900
                ? 4
                : logicalWidth >= 640
                    ? 3
                    : logicalWidth >= 360
                        ? 2
                        : 1;
        final width = columns == 1
            ? constraints.maxWidth * .86
            : (constraints.maxWidth - (columns - 1) * 10) / columns;
        final railExtent = widget.products.length * width +
            (widget.products.length - 1) * 10 -
            constraints.maxWidth;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700))),
                if (widget.action != null)
                  TextButton(
                      onPressed: widget.onAction, child: Text(widget.action!)),
                if (constraints.maxWidth >= 600 &&
                    widget.products.length > columns)
                  AnimatedBuilder(
                      animation: _scroll,
                      builder: (context, _) {
                        final offset =
                            _scroll.hasClients ? _scroll.offset : 0.0;
                        final hasPrevious = offset > 0;
                        final hasNext = offset < railExtent - .5;
                        return Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: 'Productos anteriores',
                              onPressed: hasPrevious ? () => _move(-1) : null,
                              icon: _HomeAngle(
                                  reverse: true, enabled: hasPrevious)),
                          IconButton(
                              tooltip: 'Más productos',
                              onPressed: hasNext ? () => _move(1) : null,
                              icon: _HomeAngle(enabled: hasNext)),
                        ]);
                      }),
              ]),
              const SizedBox(height: 4),
              Text(widget.subtitle,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        for (final product in widget.products) ...[
                          if (product != widget.products.first)
                            const SizedBox(width: 10),
                          SizedBox(
                              width: width,
                              child: HeroMode(
                                  enabled: false,
                                  child: AliadoProductCard(
                                    part: product,
                                    profile: widget.profile,
                                    compact: true,
                                    onTap: () => CatalogRouteLock.push(
                                        context,
                                        MaterialPageRoute<void>(
                                            builder: (_) => ProductDetailScreen(
                                                part: product))),
                                    onImporterTap: product.ownerId == null
                                        ? null
                                        : () => CatalogRouteLock.push(
                                            context,
                                            MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    ImporterStoreProfileScreen(
                                                        importerId:
                                                            product.ownerId!,
                                                        viewer:
                                                            widget.profile))),
                                  ))),
                        ],
                      ]))),
            ]);
      });
}

class _HomeAngle extends StatelessWidget {
  const _HomeAngle({
    this.size = 24,
    this.color,
    this.reverse = false,
    this.enabled,
  });

  final double size;
  final Color? color;
  final bool reverse;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark ? 'dark' : 'light';
    final variant = enabled == true ? 'normal' : 'disabled';
    final icon = SvgPicture.asset(
      enabled == null
          ? 'assets/angulo/angulo-pequeno-derecho.svg'
          : 'assets/angulo/$palette-$variant.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
      colorFilter: enabled == null
          ? ColorFilter.mode(
              color ??
                  IconTheme.of(context).color ??
                  theme.colorScheme.onSurface,
              BlendMode.srcIn)
          : null,
    );
    return reverse ? Transform.flip(flipX: true, child: icon) : icon;
  }
}

class _CategoryShortcut extends StatelessWidget {
  const _CategoryShortcut(
      {required this.label, required this.onTap, this.illustrated = false});
  final String label;
  final VoidCallback onTap;
  final bool illustrated;

  @override
  Widget build(BuildContext context) {
    final art = CatalogCategoryArt.forLabel(label);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            backgroundColor: art == null || !illustrated
                ? AppColors.surfaceTinted
                : dark
                    ? Color.lerp(AppColors.card, art.ink, .20)
                    : art.surface,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Transform.scale(
            scale: switch (art) {
              CatalogCategoryArt.tires => 1.24,
              CatalogCategoryArt.transmission => 1.28,
              _ => 1,
            },
            child: CatalogCategoryIcon(
              art: art,
              size: illustrated ? 54 : 42,
              color: art == null ? AppColors.brandLink : null,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
              height: MediaQuery.textScalerOf(context).scale(28.8),
              child: Center(
                child: Text(catalogCategoryDisplayLabel(label),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: illustrated ? FontWeight.w700 : null)),
              ))
        ]));
  }
}
