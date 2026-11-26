part of 'aliado_home_dashboard.dart';

/// Inicio del panel tienda minorista en el shell de escritorio.
/// El panel móvil sigue en [aliado_home_mobile.dart] y no usa estos widgets.
extension _AliadoHomeWeb on _AliadoHomeDashboardState {
  Widget _webHome() {
    final theme = B2BThemeExtension.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: Column(children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<AliadoHomeData>(
              future: _data,
              builder: (context, snapshot) {
                return CustomScrollView(
                  key: const PageStorageKey('aliado-inicio'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: _webSlivers(snapshot),
                );
              },
            ),
          ),
        ),
        CatalogCartBar(onOpen: _cart),
      ]),
    );
  }

  List<PromoCampaignModel> _activeWebBillboards(AliadoHomeData? data) {
    if (data == null) return const [];
    final boards = [
      for (final promo in data.promotions)
        if (promo.isBanner &&
            promo.isActive &&
            promo.isScheduleLive &&
            promo.hasDisplayCreative)
          promo,
    ]..sort((a, b) {
        final rank = b.priority.compareTo(a.priority);
        if (rank != 0) return rank;
        return (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
    return boards;
  }

  Widget _webHeroBanner(AliadoHomeData? data) {
    final boards = _activeWebBillboards(data);
    if (boards.isEmpty) return _WebHomeHero(onCatalog: _catalog);
    return _WebBillboardHero(
      campaigns: boards,
      onOpen: _openHomeCampaign,
      onCatalog: _catalog,
    );
  }

  List<Widget> _webSlivers(AsyncSnapshot<AliadoHomeData> snapshot) {
    final data = snapshot.data;
    final theme = B2BThemeExtension.of(context);
    final warning = EntrepreneurFirstPurchaseWarningBanner.maybe(widget.profile);
    final entrepreneur = warning == null
        ? EntrepreneurRailStatusCard.homeBanner(widget.profile)
        : null;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _webHeroBanner(data),
        ),
      ),
      if (warning != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(child: warning),
        )
      else if (entrepreneur != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(child: entrepreneur),
        ),
      if (snapshot.connectionState != ConnectionState.done && data == null)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      if (snapshot.hasError || (data?.errors.isNotEmpty ?? false))
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  snapshot.hasError
                      ? 'No pudimos cargar Inicio.'
                      : 'No pudimos cargar ${data!.errors.join(', ')}.',
                  style: TextStyle(color: theme.textPrimary),
                ),
                TextButton(onPressed: _refresh, child: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      if (data != null) ..._webSections(data, theme, snapshot.connectionState),
    ];
  }

  List<AliadoCatalogCategoryGroup> _webExploreCategories(AliadoHomeData data) =>
      _webAllCategories(data);

  List<AliadoCatalogCategoryGroup> _webAllCategories(AliadoHomeData data) {
    if (data.stockIndex.isNotEmpty) {
      return prioritizeHomeCategories(
        webStoreCategoryFamiliesFromStock(
          data.stockIndex,
          includeEmpty: true,
        ),
      );
    }
    if (data.categoryLabels.isEmpty) return data.categories;
    return prioritizeHomeCategories(
      webStoreCategoryFamilies(data.categoryLabels, includeEmpty: true),
    );
  }

  List<Widget> _webSections(
    AliadoHomeData data,
    B2BThemeExtension theme,
    ConnectionState connection,
  ) {
    final brands = _webBrands(data);
    final explore = _webExploreCategories(data);
    return [
      if (explore.isNotEmpty)
        _webBlock(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _webHeading(
                'Explora por categoría',
                action: 'Ver todas',
                onAction: () => _categories(
                  data,
                  groups: _webAllCategories(data),
                  includeBlankAccessories: data.categoryLabels.isNotEmpty,
                ),
              ),
              _WebCategoryRail(
                groups: explore,
                onOpen: (group) => _openCategory(
                  group,
                  includeBlankCategory: data.categoryLabels.isNotEmpty &&
                      group.label == 'Accesorios',
                ),
              ),
            ],
          ),
          top: 16,
        ),
      if (connection == ConnectionState.done && data.activeOrders > 0)
        _webBlock(
          _webLinkCard(
            theme,
            icon: LucideGlyph.van,
            title: data.activeOrders == 1
                ? '1 pedido en curso'
                : '${data.activeOrders} pedidos en curso',
            action: 'Ver seguimiento',
            onTap: MainShellTabController.navigateToPedidosTab,
          ),
        ),
      if (data.buyAgain.isNotEmpty)
        _webBlock(
          _WebHomeRail(
            title: 'Compra de nuevo',
            subtitle: 'Tus compras, con precio y stock actuales.',
            action: 'Mis pedidos',
            onAction: MainShellTabController.navigateToPedidosTab,
            products: data.buyAgain,
            cardBuilder: (part) => _webPartCard(part, theme),
          ),
        )
      else if (data.errors.isEmpty)
        _webBlock(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu próxima compra comienza aquí',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Explora el catálogo. Aquí podrás volver a comprar tus repuestos.',
                style: TextStyle(color: theme.textSecondary),
              ),
              TextButton.icon(
                onPressed: _catalog,
                icon: const _HomeAngle(size: 18),
                label: const Text('Explorar catálogo'),
              ),
            ],
          ),
        ),
      if (data.bestSellers.isNotEmpty)
        _webBlock(
          _WebHomeRail(
            title: 'Más vendidos',
            subtitle: 'Últimos 30 días',
            products: data.bestSellers,
            cardBuilder: (part) => _webPartCard(part, theme, favorite: true),
          ),
        )
      else if (data.errors.isEmpty)
        _webBlock(
          Text(
            'Los más vendidos aparecerán cuando haya entregas recientes.',
            style: TextStyle(color: theme.textSecondary),
          ),
        ),
      if (data.newArrivals.isNotEmpty)
        _webBlock(
          _WebHomeRail(
            title: 'Novedades',
            subtitle: 'Repuestos recién publicados por tus proveedores.',
            products: data.newArrivals.take(8).toList(growable: false),
            cardBuilder: (part) => _webPartCard(part, theme, favorite: true),
          ),
        ),
      if (brands.isNotEmpty)
        _webBlock(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _webHeading(
                'Compra por marca',
                action: brands.length > 8 ? 'Ver todas' : null,
                onAction: () => _webBrandDialog(brands),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final brand in brands.take(8))
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: OutlinedButton(
                    onPressed: () =>
                        _catalog(CatalogFilters(brandField: brand)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textPrimary,
                      side: BorderSide(color: theme.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      brand.value.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ),
              ]),
            ],
          ),
          top: 8,
        ),
      if (data.suppliers.isNotEmpty) ...[
        _webBlock(
          _webSuppliersPanel(data, theme),
        ),
        _webBlock(
          _webLinkCard(
            theme,
            icon: LucideGlyph.messageCircle,
            title: '¿No encuentras un repuesto?',
            subtitle: 'Consulta con un proveedor',
            action: 'Consultar',
            onTap: () => CatalogRouteLock.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) =>
                        NewConsultationScreen(suppliers: data.suppliers))),
          ),
          top: 10,
        ),
      ],
      _webBlock(
        _HomeRecentSection(
          viewerId: widget.profile.id,
          builder: (items) => _WebHomeRail(
            title: 'Vistos recientemente',
            subtitle: 'Repuestos que abriste en esta tienda.',
            products: items,
            cardBuilder: (part) => _webPartCard(part, theme, favorite: true),
          ),
        ),
        top: 8,
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverToBoxAdapter(
          child: Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              onPressed: _catalog,
              icon: LucideIcon(LucideGlyph.grid, size: 18, color: theme.brand),
              label: const Text('Explorar todo el catálogo'),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _webHeading(String title,
      {String? subtitle, String? action, VoidCallback? onAction}) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                  height: 1.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: theme.textSecondary),
                ),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Widget _webBlock(Widget child, {double top = 18}) => SliverPadding(
        padding: EdgeInsets.fromLTRB(16, top, 16, 0),
        sliver: SliverToBoxAdapter(child: child),
      );

  Widget _webPartCard(PartModel part, B2BThemeExtension theme,
      {bool favorite = true}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.borderSubtle)),
              ),
              child: SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: theme.surfaceCard,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: _WebHomeProductPhoto(part: part),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(onTap: () => _openPart(part)),
                  ),
                ),
                if (favorite)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: FavoriteHeartButton(
                      productId: part.id,
                      compact: true,
                    ),
                  ),
              ]),
            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => _openPart(part),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: theme.textPrimary,
                          ),
                        ),
                        if (part.ownerBusinessName?.trim().isNotEmpty == true)
                          Text(
                            part.ownerBusinessName!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _price(part),
                  const SizedBox(height: 4),
                  ProductStockSummary(part: part),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: _WebAddButton(
                part: part,
                profile: widget.profile,
                onDetails: () => _openPart(part),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webSuppliersPanel(AliadoHomeData data, B2BThemeExtension theme) {
    final featured = _featuredSuppliers(data).toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _webHeading(
              'Tus proveedores',
              action: 'Ver tiendas',
              onAction: () => CatalogRouteLock.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          SupplierDirectoryScreen(viewer: widget.profile))),
            ),
            Row(children: [
              for (final supplier in featured)
                Expanded(child: _webSupplierTile(supplier, theme)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _webSupplierTile(ImporterOption supplier, B2BThemeExtension theme) {
    return InkWell(
      onTap: () => _openStore(supplier),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(children: [
          _HomeLogo(path: supplier.logoStoragePath, size: 40),
          const SizedBox(height: 6),
          Text(
            supplier.businessName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
            ),
          ),
          Text(
            supplier.ubicacionLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: theme.textSecondary),
          ),
        ]),
      ),
    );
  }

  Widget _webLinkCard(
    B2BThemeExtension theme, {
    required LucideGlyph icon,
    required String title,
    String? subtitle,
    required String action,
    required VoidCallback onTap,
  }) {
    return Material(
      color: theme.brandContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            LucideIcon(icon, color: theme.brand, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              action,
              style: TextStyle(
                color: theme.brand,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 2),
            _HomeAngle(size: 16, color: theme.brand),
          ]),
        ),
      ),
    );
  }

  List<MapEntry<String, String>> _webBrands(AliadoHomeData data) {
    final brands = <String, MapEntry<String, String>>{};
    for (final product in [
      ...data.newArrivals,
      ...data.buyAgain,
      ...data.bestSellers,
    ]) {
      for (final entry in productCustomFieldValues(product.customFields).entries) {
        final key = entry.key.toLowerCase().replaceFirst('col_', '');
        if (!const {'marca', 'brand', 'marca_proveedor'}.contains(key)) continue;
        if (!parseAliadoVisibleCustomFieldKeys(product.customFields)
            .contains(entry.key)) {
          continue;
        }
        final value = product.customFields[entry.key];
        if (value is! String || value.trim().isEmpty) continue;
        brands.putIfAbsent(
          value.trim().toLowerCase(),
          () => MapEntry(entry.key, value),
        );
      }
    }
    return brands.values.toList(growable: false);
  }

  Future<void> _webBrandDialog(List<MapEntry<String, String>> brands) async {
    final theme = B2BThemeExtension.of(context);
    final selected = await showDialog<MapEntry<String, String>>(
      context: context,
      barrierColor: theme.textPrimary.withOpacity(0.35),
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.dialogSurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.borderSubtle),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      'Marcas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: LucideIcon(LucideGlyph.close, color: theme.textSecondary),
                  ),
                ]),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: brands.length,
                  itemBuilder: (_, index) {
                    final brand = brands[index];
                    return ListTile(
                      title: Text(
                        brand.value.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textPrimary),
                      ),
                      trailing: const _HomeAngle(),
                      onTap: () => Navigator.pop(dialogContext, brand),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    _catalog(CatalogFilters(brandField: selected));
  }
}

class _WebHomeRail extends StatefulWidget {
  const _WebHomeRail({
    required this.title,
    required this.subtitle,
    required this.products,
    required this.cardBuilder,
    this.action,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final List<PartModel> products;
  final Widget Function(PartModel part) cardBuilder;
  final String? action;
  final VoidCallback? onAction;

  @override
  State<_WebHomeRail> createState() => _WebHomeRailState();
}

class _WebHomeRailState extends State<_WebHomeRail> {
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
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final logicalWidth = (constraints.maxWidth + 32) / (scale < 1 ? 1 : scale);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
            if (widget.action != null)
              TextButton(
                onPressed: widget.onAction,
                child: Text(
                  widget.action!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            if (constraints.maxWidth >= 600 && widget.products.length > columns)
              AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                  final hasPrevious = offset > 0;
                  final hasNext = offset < railExtent - .5;
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Productos anteriores',
                      onPressed: hasPrevious ? () => _move(-1) : null,
                      icon: _HomeAngle(reverse: true, enabled: hasPrevious),
                    ),
                    IconButton(
                      tooltip: 'Más productos',
                      onPressed: hasNext ? () => _move(1) : null,
                      icon: _HomeAngle(enabled: hasNext),
                    ),
                  ]);
                },
              ),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final product in widget.products) ...[
                    if (product != widget.products.first) const SizedBox(width: 10),
                    SizedBox(width: width, child: widget.cardBuilder(product)),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _WebHomeProductPhoto extends StatelessWidget {
  const _WebHomeProductPhoto({required this.part});

  final PartModel part;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final url = part.coverImageUrl?.trim();
    if (url == null || url.isEmpty) {
      return Center(
        child: LucideIcon(LucideGlyph.package, size: 28, color: theme.textMuted),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => Center(
        child: LucideIcon(LucideGlyph.package, size: 28, color: theme.textMuted),
      ),
    );
  }
}

class _WebStockBadge extends StatelessWidget {
  const _WebStockBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.textSecondary,
          ),
        ),
      ),
    );
  }
}

extension _WebCategoryDialogHost on _AliadoHomeDashboardState {
  void _showWebCategoryDialog({
    required List<AliadoCatalogCategoryGroup> groups,
    required bool includeBlankAccessories,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final media = MediaQuery.sizeOf(dialogContext);
        final theme = B2BThemeExtension.of(dialogContext);
        final available = media.width - 48;
        final width = available > 880 ? 880.0 : available;
        return Dialog(
          backgroundColor: theme.dialogSurface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.borderSubtle),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.height * 0.78),
            child: SizedBox(
              width: width,
              child: _WebCategoryDialog(
              groups: groups,
              includeBlankAccessories: includeBlankAccessories,
              onClose: () => Navigator.pop(dialogContext),
              onOpen: (group, blank) {
                Navigator.pop(dialogContext);
                _openCategory(group, includeBlankCategory: blank);
              },
            ),
            ),
          ),
        );
      },
    );
  }
}

class _WebCategoryDialog extends StatelessWidget {
  const _WebCategoryDialog({
    required this.groups,
    required this.includeBlankAccessories,
    required this.onClose,
    required this.onOpen,
  });

  final List<AliadoCatalogCategoryGroup> groups;
  final bool includeBlankAccessories;
  final VoidCallback onClose;
  final void Function(AliadoCatalogCategoryGroup group, bool includeBlank) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categorías',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Familias y subcategorías del catálogo.',
                      style: TextStyle(fontSize: 13, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar categorías',
                onPressed: onClose,
                icon: LucideIcon(LucideGlyph.close, size: 18, color: theme.textSecondary),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.borderSubtle),
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? 2 : 1;
              final columnsOf = List.generate(columns, (_) => <Widget>[]);
              for (var i = 0; i < groups.length; i++) {
                columnsOf[i % columns].add(_family(theme, groups[i]));
              }
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < columns; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: Column(children: columnsOf[i])),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _family(B2BThemeExtension theme, AliadoCatalogCategoryGroup group) {
    final title = catalogCategoryDisplayLabel(group.label);
    final blank = includeBlankAccessories && group.label == 'Accesorios';
    final mark = _availability(theme, group);
    final header = Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
            ),
          ),
        ),
        if (mark != null) ...[
          const SizedBox(width: 8),
          mark,
        ],
      ],
    );
    if (group.children.isEmpty) {
      return ListTile(
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: CatalogCategoryIcon(
          art: CatalogCategoryArt.forLabel(group.label),
          size: 22,
        ),
        title: header,
        onTap: () => onOpen(group, blank),
      );
    }
    return ExpansionTile(
      visualDensity: VisualDensity.compact,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.only(bottom: 4),
      leading: CatalogCategoryIcon(
        art: CatalogCategoryArt.forLabel(group.label),
        size: 22,
      ),
      title: header,
      children: [
        ListTile(
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.only(left: 48, right: 8),
          title: Text(
            'Ver todo en $title',
            style: TextStyle(color: theme.textPrimary, fontSize: 13),
          ),
          onTap: () => onOpen(group, blank),
        ),
        for (final child in group.children)
          ListTile(
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.only(left: 48, right: 8),
            title: Text(
              categoryLeaf(child.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textPrimary, fontSize: 13),
            ),
            trailing: _availability(theme, child),
            onTap: () => onOpen(child, false),
          ),
      ],
    );
  }

  Widget? _availability(B2BThemeExtension theme, AliadoCatalogCategoryGroup group) {
    if (!group.hasInventory) {
      return const _WebStockBadge(label: 'Sin disponibilidad');
    }
    final count = group.productIds.length;
    if (count == 0) return null;
    return Text(
      count == 1 ? '1 disponible' : '$count disponibles',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: theme.textSecondary,
      ),
    );
  }
}

class _WebCategoryRail extends StatefulWidget {
  const _WebCategoryRail({required this.groups, required this.onOpen});

  final List<AliadoCatalogCategoryGroup> groups;
  final ValueChanged<AliadoCatalogCategoryGroup> onOpen;

  @override
  State<_WebCategoryRail> createState() => _WebCategoryRailState();
}

class _WebCategoryRailState extends State<_WebCategoryRail>
    with TickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _enter;
  late final Listenable _motion;
  late final AnimationController _cruise;
  Duration _cruiseStamp = Duration.zero;
  double _pageStep = 220;
  double _loopWidth = 0;
  int _slots = 1;
  bool _driving = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..forward();
    _motion = _enter;
    _cruise = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_onCruise);
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickoff());
  }

  bool get _autoplayAllowed {
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('Test')) return false;
    return widget.groups.length > 1 &&
        !MediaQuery.disableAnimationsOf(context);
  }

  void _kickoff() {
    if (!mounted || !_scroll.hasClients) return;
    final loop = _loopWidth;
    if (loop > 1) {
      _scroll.jumpTo(loop.clamp(0.0, _scroll.position.maxScrollExtent));
    }
    setState(() {});
    if (_autoplayAllowed && !_cruise.isAnimating) _cruise.repeat();
  }

  void _onCruise() {
    final elapsed = WidgetsBinding.instance.currentFrameTimeStamp;
    final dt = (elapsed - _cruiseStamp).inMicroseconds / 1000000;
    _cruiseStamp = elapsed;
    if (!mounted || _paused || _driving || !_scroll.hasClients) return;
    if (dt <= 0 || dt > 0.08 || _loopWidth <= 1) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 1) return;
    var next = position.pixels - 42 * dt;
    if (next <= 0) next += _loopWidth;
    position.jumpTo(next.clamp(0.0, position.maxScrollExtent));
  }

  @override
  void dispose() {
    _cruise
      ..stop()
      ..dispose();
    _enter.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(double direction) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final page = _pageStep * _slots;
    final room = direction > 0
        ? position.maxScrollExtent - position.pixels
        : position.pixels;
    final span = room < page ? room : page;
    final target = (position.pixels + direction * span)
        .clamp(0.0, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 1) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    _driving = true;
    position
        .animateTo(
          target,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        )
        .whenComplete(() {
      if (mounted) _driving = false;
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients || _driving) return;
    final delta = event.scrollDelta.dx.abs() >= event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta.abs() < 0.5) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      position.jumpTo(
        (position.pixels + delta).clamp(0.0, position.maxScrollExtent),
      );
    });
  }

  double _reveal(int index) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final local = ((_enter.value - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
  }

  Widget _arrow({
    required double direction,
    required String tooltip,
    required LucideGlyph icon,
  }) {
    return ListenableBuilder(
      listenable: _scroll,
      builder: (context, _) {
        final offset = _scroll.hasClients ? _scroll.offset : 0.0;
        final max = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
        final enabled = direction < 0 ? offset > 1 : max > 1 && offset < max - 1;
        return _RailArrow(
          tooltip: tooltip,
          icon: icon,
          onPressed: enabled ? () => _move(direction) : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Row(
        children: [
          _arrow(
            direction: -1,
            tooltip: 'Categorías anteriores',
            icon: LucideGlyph.chevronLeft,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, inner) {
                const gap = 10.0;
                const minCard = 156.0;
                final count = widget.groups.length;
                var slots = count == 0
                    ? 1
                    : ((inner.maxWidth + gap) / (minCard + gap))
                        .floor()
                        .clamp(1, count);
                if (count > 1 && slots >= count) slots = count - 1;
                final gaps = slots <= 1 ? 0.0 : (slots - 1) * gap;
                final cardWidth = slots == 0
                    ? minCard
                    : (inner.maxWidth - gaps) / slots;
                _pageStep = cardWidth + gap;
                _slots = slots;
                final looped = count > 1;
                _loopWidth = looped ? count * (cardWidth + gap) : 0;
                return MouseRegion(
                  onEnter: (_) => _paused = true,
                  onExit: (_) => _paused = false,
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, _) {
                      return Listener(
                        onPointerDown: (_) => _paused = true,
                        onPointerSignal: _onPointerSignal,
                        child: ScrollConfiguration(
                          behavior: const _RailScrollBehavior(),
                          child: ListView.separated(
                            controller: _scroll,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: looped ? count * 2 : count,
                            separatorBuilder: (_, __) => const SizedBox(width: gap),
                            itemBuilder: (context, index) {
                              final revealed = _reveal(index % count);
                              return Opacity(
                                opacity: revealed,
                                child: Transform.translate(
                                  offset: Offset((revealed - 1) * 28, 0),
                                  child: _WebCategoryCard(
                                    group: widget.groups[index % count],
                                    width: cardWidth,
                                    onTap: () => widget
                                        .onOpen(widget.groups[index % count]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _arrow(
            direction: 1,
            tooltip: 'Más categorías',
            icon: LucideGlyph.chevronRight,
          ),
        ],
      ),
    );
  }
}

class _RailScrollBehavior extends MaterialScrollBehavior {
  const _RailScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class _RailArrow extends StatelessWidget {
  const _RailArrow({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final LucideGlyph icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: LucideIcon(
        icon,
        size: 18,
        color: onPressed == null ? theme.textMuted : theme.textSecondary,
      ),
    );
  }
}

class _WebCategoryCard extends StatefulWidget {
  const _WebCategoryCard({
    required this.group,
    required this.width,
    required this.onTap,
  });

  final AliadoCatalogCategoryGroup group;
  final double width;
  final VoidCallback onTap;

  @override
  State<_WebCategoryCard> createState() => _WebCategoryCardState();
}

class _WebCategoryCardState extends State<_WebCategoryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final art = CatalogCategoryArt.forLabel(widget.group.label);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: widget.width,
        margin: EdgeInsets.only(top: _hover ? 0 : 2, bottom: _hover ? 2 : 0),
        decoration: BoxDecoration(
          color: _hover ? theme.brandContainer : theme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hover ? B2BBrandHero.start : theme.borderSubtle,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.textPrimary.withOpacity(_hover ? 0.12 : 0.04),
              blurRadius: _hover ? 12 : 4,
              offset: Offset(0, _hover ? 4 : 1),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CatalogCategoryIcon(art: art, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    catalogCategoryDisplayLabel(widget.group.label),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  if (!widget.group.hasInventory) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sin disponibilidad',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: theme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebBillboardHero extends StatefulWidget {
  const _WebBillboardHero({
    required this.campaigns,
    required this.onOpen,
    required this.onCatalog,
  });

  final List<PromoCampaignModel> campaigns;
  final ValueChanged<PromoCampaignModel> onOpen;
  final VoidCallback onCatalog;

  @override
  State<_WebBillboardHero> createState() => _WebBillboardHeroState();
}

class _WebBillboardHeroState extends State<_WebBillboardHero> {
  late final PageController _page;
  Timer? _timer;
  int _index = 0;
  bool _hover = false;
  final _failed = <String>{};
  final _imageRatios = <String, double>{};

  @override
  void initState() {
    super.initState();
    _page = PageController();
    _armTimer();
  }

  @override
  void didUpdateWidget(covariant _WebBillboardHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.campaigns.length) {
      _index = 0;
      if (_page.hasClients) _page.jumpToPage(0);
    }
    _armTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  void _armTimer() {
    _timer?.cancel();
    if (widget.campaigns.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _step(1));
  }

  void _step(int direction) {
    if (!mounted || widget.campaigns.length < 2) return;
    if (_hover || MediaQuery.disableAnimationsOf(context)) return;
    final next = (_index + direction) % widget.campaigns.length;
    _go(next < 0 ? widget.campaigns.length - 1 : next);
  }

  void _go(int index) {
    if (!_page.hasClients) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _page.jumpToPage(index);
    } else {
      _page.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = [
      for (final campaign in widget.campaigns)
        if (!_failed.contains(campaign.imageUrlForWidth(1200))) campaign,
    ];
    if (live.isEmpty) return _WebHomeHero(onCatalog: widget.onCatalog);
    final theme = B2BThemeExtension.of(context);
    final several = live.length > 1;
    final active = live[_index.clamp(0, live.length - 1)];
    final usesMobileCreative = active.imagePublicUrl.trim().isEmpty;
    final width = usesMobileCreative ? active.mobileImageWidth : active.imageWidth;
    final height = usesMobileCreative ? active.mobileImageHeight : active.imageHeight;
    final estimatedRatio = width != null && height != null && width > 0 && height > 0
        ? width / height
        : usesMobileCreative
            ? PromoBannerSpec.mobileAspect
            : PromoBannerSpec.desktopAspect;
    final aspect = (_imageRatios[active.imageUrlForWidth(1200)] ?? estimatedRatio)
        .clamp(PromoBannerSpec.webFrameAspect, 10.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PromoBannerSpec.webFrameWidth),
        child: MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.textPrimary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: theme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _page,
                  itemCount: live.length,
                  physics: several
                      ? const PageScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final campaign = live[index];
                    final url = campaign.imageUrlForWidth(1200);
                    return InkWell(
                      onTap: campaign.isTappable
                          ? () => widget.onOpen(campaign)
                          : null,
                      child: PromoCreativeImage(
                        url: url,
                        fit: BoxFit.contain,
                        onImageRatio: (ratio) {
                          if (mounted && _imageRatios[url] != ratio) {
                            setState(() => _imageRatios[url] = ratio);
                          }
                        },
                        onLoadFailed: (failed) {
                          if (_failed.add(failed) && mounted) setState(() {});
                        },
                      ),
                    );
                  },
                ),
                if (several)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: _BillboardArrow(
                      visible: _hover,
                      icon: LucideGlyph.chevronLeft,
                      tooltip: 'Valla anterior',
                      onPressed: () => _go(
                        (_index - 1 + live.length) % live.length,
                      ),
                    ),
                  ),
                if (several)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: _BillboardArrow(
                      visible: _hover,
                      icon: LucideGlyph.chevronRight,
                      tooltip: 'Valla siguiente',
                      onPressed: () => _go((_index + 1) % live.length),
                    ),
                  ),
                if (several)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < live.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: i == _index ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? B2BBrandHero.start
                                    : theme.surfaceCard.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}

class _BillboardArrow extends StatelessWidget {
  const _BillboardArrow({
    required this.visible,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool visible;
  final LucideGlyph icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Center(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: IgnorePointer(
          ignoring: !visible,
          child: Material(
            color: theme.surfaceCard.withOpacity(0.92),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              icon: LucideIcon(icon, size: 18, color: theme.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebHomeHero extends StatelessWidget {
  const _WebHomeHero({required this.onCatalog});

  static const asset = 'assets/b2b-hero-surte-tienda.jpg';

  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PromoBannerSpec.webFrameWidth),
        child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: B2BBrandHero.start,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: PromoBannerSpec.webFrameAspect,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const Image(
                    image: AssetImage(asset),
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    gaplessPlayback: true,
                  ),
                  Positioned(
                    left: width * 0.046,
                    bottom: height * 0.11,
                    child: FilledButton(
                      onPressed: onCatalog,
                      style: FilledButton.styleFrom(
                        backgroundColor: B2BBrandHero.foreground,
                        foregroundColor: B2BBrandHero.accentInk,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: width * 0.026,
                          vertical: height * 0.04,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: TextStyle(
                          fontSize: (width * 0.018).clamp(13.0, 17.0),
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      child: const Text('Explora el catálogo'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
        ),
      ),
    );
  }
}

class _WebAddButton extends StatelessWidget {
  const _WebAddButton({
    required this.part,
    required this.profile,
    required this.onDetails,
  });

  final PartModel part;
  final ProfileModel profile;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final cart = CartService.instance;
    return ListenableBuilder(
      listenable: cart,
      builder: (_, __) {
        final added = CartProductActions.lineFor(part, cart) != null;
        final blocked = CartProductActions.blockReason(
          part: part,
          profile: profile,
          cart: cart,
        );
        final chooseVariant =
            part.hasVariantFamily || part.variantChoices.isNotEmpty;
        final opensDetails = chooseVariant || blocked != null;
        final label = added
            ? 'En carrito'
            : chooseVariant
                ? 'Ver opciones'
                : opensDetails
                    ? 'Ver detalle'
                    : 'Agregar';
        final action = added
            ? null
            : opensDetails
                ? onDetails
                : () => CartProductActions.addMinimum(
                      part: part,
                      profile: profile,
                      cart: cart,
                    );
        final radius = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        );
        return Tooltip(
          message: added
              ? '${part.nombre} ya está en el carrito'
              : '$label ${part.nombre}',
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: action,
              style: ButtonStyle(
                animationDuration: const Duration(milliseconds: 160),
                elevation: const WidgetStatePropertyAll(0),
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                shape: WidgetStatePropertyAll(radius),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (added) return theme.brandContainer;
                  if (states.contains(WidgetState.hovered)) {
                    return Color.lerp(B2BBrandHero.start, B2BBrandHero.end, .28);
                  }
                  return B2BBrandHero.start;
                }),
                foregroundColor: WidgetStatePropertyAll(
                  added ? B2BBrandHero.start : B2BBrandHero.foreground,
                ),
                overlayColor: WidgetStatePropertyAll(
                  B2BBrandHero.foreground.withOpacity(added ? 0 : .08),
                ),
                side: WidgetStatePropertyAll(
                  added
                      ? BorderSide(color: B2BBrandHero.start.withOpacity(.55))
                      : BorderSide.none,
                ),
              ),
              icon: LucideIcon(
                added
                    ? LucideGlyph.check
                    : opensDetails
                        ? LucideGlyph.arrowRight
                        : LucideGlyph.handbag,
                size: 16,
                color: added ? B2BBrandHero.start : B2BBrandHero.foreground,
              ),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        );
      },
    );
  }
}
