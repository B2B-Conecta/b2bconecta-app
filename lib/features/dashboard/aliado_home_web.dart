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

  List<Widget> _webSlivers(AsyncSnapshot<AliadoHomeData> snapshot) {
    final data = snapshot.data;
    final theme = B2BThemeExtension.of(context);
    final warning = EntrepreneurFirstPurchaseWarningBanner.maybe(widget.profile);
    final entrepreneur = warning == null
        ? EntrepreneurRailStatusCard.homeBanner(widget.profile)
        : null;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _WebHomeHero(onCatalog: _catalog),
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

  List<Widget> _webSections(
    AliadoHomeData data,
    B2BThemeExtension theme,
    ConnectionState connection,
  ) {
    final brands = _webBrands(data);
    return [
      if (data.categories.isNotEmpty)
        _webBlock(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _webHeading(
                'Explora por categoría',
                action: 'Ver todas',
                onAction: () => _categories(data),
              ),
              LayoutBuilder(builder: (context, bounds) {
                final count =
                    MediaQuery.textScalerOf(context).scale(14) > 19 ? 2 : 4;
                final width = (bounds.maxWidth - (count - 1) * 8) / count;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final group in data.categories.take(4))
                    SizedBox(
                      width: width,
                      child: _CategoryShortcut(
                        label: group.label,
                        illustrated: true,
                        onTap: () => _openCategory(group),
                      ),
                    ),
                ]);
              }),
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
            onTap: () => _webSupplierDialog(data.suppliers, consult: true),
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
    final photoFill = Theme.of(context).brightness == Brightness.dark
        ? theme.surfaceElevated
        : theme.inputFill;
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
            SizedBox(
              height: 148,
              child: Stack(children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: photoFill,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox.expand(
                        child: _HomeProductPhoto(
                          part: part,
                          blendWithCard: true,
                        ),
                      ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                  const SizedBox(height: 10),
                  _WebAddButton(
                    part: part,
                    profile: widget.profile,
                    onDetails: () => _openPart(part),
                  ),
                ],
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
              onAction: () => _webSupplierDialog(data.suppliers, consult: false),
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

  Future<void> _webSupplierDialog(List<ImporterOption> suppliers,
      {required bool consult}) async {
    final theme = B2BThemeExtension.of(context);
    final selected = await showDialog<ImporterOption>(
      context: context,
      barrierColor: theme.textPrimary.withOpacity(0.35),
      builder: (dialogContext) => _WebSupplierPickerDialog(
        suppliers: suppliers,
        consult: consult,
      ),
    );
    if (!mounted || selected == null) return;
    if (!consult) {
      _openStore(selected);
      return;
    }
    await CatalogRouteLock.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _HomeSupplierConversation(supplier: selected),
      ),
    );
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

class _WebHomeHero extends StatelessWidget {
  const _WebHomeHero({required this.onCatalog});

  static const asset = 'assets/b2b-hero-surte-tienda.jpg';

  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
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
          aspectRatio: 1024 / 382,
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
                    alignment: Alignment.center,
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
              label: Text(label),
            ),
          ),
        );
      },
    );
  }
}

class _WebSupplierPickerDialog extends StatefulWidget {
  const _WebSupplierPickerDialog({
    required this.suppliers,
    required this.consult,
  });

  final List<ImporterOption> suppliers;
  final bool consult;

  @override
  State<_WebSupplierPickerDialog> createState() =>
      _WebSupplierPickerDialogState();
}

class _WebSupplierPickerDialogState extends State<_WebSupplierPickerDialog> {
  static const _pageSize = 5;
  final _query = TextEditingController();
  String? _estado;
  int _page = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<String> get _estados {
    final values = <String>{
      for (final supplier in widget.suppliers)
        if (supplier.estado?.trim().isNotEmpty == true) supplier.estado!.trim(),
    };
    final list = values.toList()..sort();
    return list;
  }

  List<ImporterOption> get _visible {
    final query = _query.text.trim().toLowerCase();
    return [
      for (final supplier in widget.suppliers)
        if (_estado == null || supplier.estado?.trim() == _estado)
          if (query.isEmpty ||
              supplier.businessName.toLowerCase().contains(query) ||
              (supplier.ciudad?.toLowerCase().contains(query) ?? false) ||
              (supplier.estado?.toLowerCase().contains(query) ?? false))
            supplier,
    ];
  }

  void _clear() {
    _query.clear();
    setState(() {
      _estado = null;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final visible = _visible;
    final estados = _estados;
    return Dialog(
      backgroundColor: theme.dialogSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    widget.consult ? 'Elige un proveedor' : 'Tiendas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: LucideIcon(LucideGlyph.close, color: theme.textSecondary),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() => _page = 0),
                  style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar proveedor, ciudad o estado...',
                    hintStyle: TextStyle(color: theme.textMuted, fontSize: 13.5),
                    filled: true,
                    fillColor: theme.inputFill,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: LucideIcon(
                        LucideGlyph.search,
                        size: 18,
                        color: theme.textSecondary,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                      maxWidth: 40,
                      maxHeight: 40,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: B2BBrandHero.start),
                    ),
                  ),
                ),
              ),
              if (estados.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _estadoChip(theme, 'Todos', null),
                      for (final estado in estados) ...[
                        const SizedBox(width: 8),
                        _estadoChip(theme, estado, estado),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (visible.isEmpty)
                _empty(theme)
              else ...[
                for (final supplier in _pageItems(visible)) ...[
                  _WebSupplierPickCard(
                    supplier: supplier,
                    consult: widget.consult,
                    onTap: () => Navigator.pop(context, supplier),
                  ),
                  const SizedBox(height: 8),
                ],
                _pager(theme, visible.length),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<ImporterOption> _pageItems(List<ImporterOption> visible) {
    final pages = (visible.length / _pageSize).ceil();
    final page = _page.clamp(0, pages - 1);
    final start = page * _pageSize;
    final end = start + _pageSize > visible.length
        ? visible.length
        : start + _pageSize;
    return visible.sublist(start, end);
  }

  void _goToPage(int page, int pages) =>
      setState(() => _page = page.clamp(0, pages - 1));

  Widget _pager(B2BThemeExtension theme, int total) {
    final pages = (total / _pageSize).ceil();
    final page = _page.clamp(0, pages - 1);
    final start = page * _pageSize + 1;
    final end = (page + 1) * _pageSize > total ? total : (page + 1) * _pageSize;
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 8),
      child: Row(children: [
        Expanded(
          child: Text(
            'Mostrando $start–$end de $total proveedores',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: page == 0 ? null : () => _goToPage(page - 1, pages),
          style: TextButton.styleFrom(foregroundColor: B2BBrandHero.start),
          child: const Text('Anterior'),
        ),
        SizedBox(
          height: 32,
          width: pages > 5 ? 148 : pages * 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < pages; i++) _pageButton(i, page, pages),
            ],
          ),
        ),
        TextButton(
          onPressed: page >= pages - 1 ? null : () => _goToPage(page + 1, pages),
          style: TextButton.styleFrom(foregroundColor: B2BBrandHero.start),
          child: const Text('Siguiente'),
        ),
      ]),
    );
  }

  Widget _pageButton(int index, int page, int pages) {
    final selected = index == page;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? B2BBrandHero.start : B2BBrandHero.foreground.withOpacity(0),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _goToPage(index, pages),
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? B2BBrandHero.foreground : B2BBrandHero.start,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _estadoChip(B2BThemeExtension theme, String label, String? value) {
    final selected = _estado == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() {
        _estado = value;
        _page = 0;
      }),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: selected ? B2BBrandHero.foreground : theme.textPrimary,
      ),
      selectedColor: B2BBrandHero.start,
      backgroundColor: theme.surfaceSubtle,
      side: BorderSide(
        color: selected ? B2BBrandHero.start : theme.borderSubtle,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _empty(B2BThemeExtension theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(LucideGlyph.search, size: 28, color: theme.textMuted),
            const SizedBox(height: 10),
            Text(
              'Ningún proveedor coincide',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Prueba otro nombre, ciudad o estado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _clear, child: const Text('Limpiar filtros')),
          ],
        ),
      ),
    );
  }
}

class _WebSupplierPickCard extends StatefulWidget {
  const _WebSupplierPickCard({
    required this.supplier,
    required this.consult,
    required this.onTap,
  });

  final ImporterOption supplier;
  final bool consult;
  final VoidCallback onTap;

  @override
  State<_WebSupplierPickCard> createState() => _WebSupplierPickCardState();
}

class _WebSupplierPickCardState extends State<_WebSupplierPickCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final supplier = widget.supplier;
    final action = widget.consult ? 'Consultar' : 'Ver tienda';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _hover ? theme.brandContainer : theme.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hover ? B2BBrandHero.start.withOpacity(.45) : theme.borderSubtle,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(children: [
                _HomeLogo(path: supplier.logoStoragePath, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        supplier.ubicacionLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.textSecondary,
                        ),
                      ),
                      if (supplier.isCatalogFeatured) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Destacado',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: B2BBrandHero.start,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  action,
                  style: const TextStyle(
                    color: B2BBrandHero.start,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 2),
                const _HomeAngle(size: 16, color: B2BBrandHero.start),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
