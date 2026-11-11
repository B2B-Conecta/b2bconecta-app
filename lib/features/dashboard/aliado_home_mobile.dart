part of 'aliado_home_dashboard.dart';

const _homeNavy = Color(0xFF08234C);

class _HomeLogo extends StatefulWidget {
  const _HomeLogo({required this.path, required this.size});
  final String? path;
  final double size;

  @override
  State<_HomeLogo> createState() => _HomeLogoState();
}

class _HomeLogoState extends State<_HomeLogo> {
  late Future<String?> _url;

  Future<String?> _resolve() async {
    final path = widget.path?.trim();
    if (path == null || path.isEmpty) return null;
    try {
      return await SupabaseService.createSignedUrlForProfileLogo(path);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _url = _resolve();
  }

  @override
  void didUpdateWidget(covariant _HomeLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _url = _resolve();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: LucideIcon(LucideGlyph.store,
          size: widget.size * .52, color: AppColors.brandLink),
    );
    return SizedBox.square(
        dimension: widget.size,
        child: ClipOval(
          child: ColoredBox(
              color: AppColors.card,
              child: FutureBuilder<String?>(
                future: _url,
                builder: (_, snapshot) => snapshot.data?.isNotEmpty == true
                    ? Image.network(snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => fallback)
                    : fallback,
              )),
        ));
  }
}

class _HomeProductPhoto extends StatelessWidget {
  const _HomeProductPhoto({required this.part, this.blendWithCard = false});
  final PartModel part;
  final bool blendWithCard;

  @override
  Widget build(BuildContext context) {
    final url = part.coverImageUrl;
    final fallback = Center(
        child: LucideIcon(LucideGlyph.package,
            color: AppColors.textSecondary, size: 25));
    return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
            color: blendWithCard ? Colors.transparent : AppColors.card,
            child: url == null || url.isEmpty
                ? fallback
                : Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => fallback)));
  }
}

class _InCartHandbag extends StatelessWidget {
  const _InCartHandbag({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light';
    return SvgPicture.asset(
      'assets/handbag_solid/$theme-selected-disabled.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

class _HomeAddButton extends StatelessWidget {
  const _HomeAddButton(
      {required this.part,
      required this.profile,
      required this.onDetails,
      this.showLabel = false});
  final PartModel part;
  final ProfileModel profile;
  final VoidCallback onDetails;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    return ListenableBuilder(
        listenable: cart,
        builder: (_, __) {
          final added = CartProductActions.lineFor(part, cart) != null;
          final blocked = CartProductActions.blockReason(
              part: part, profile: profile, cart: cart);
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
          void add() {
            CartProductActions.addMinimum(
                part: part, profile: profile, cart: cart);
          }

          final action = added
              ? null
              : opensDetails
                  ? onDetails
                  : add;
          return Tooltip(
              message: added
                  ? '${part.nombre} ya está en el carrito'
                  : '$label ${part.nombre}',
              child: showLabel
                  ? FilledButton.icon(
                      onPressed: action,
                      style: FilledButton.styleFrom(
                          backgroundColor: _homeNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                          minimumSize: const Size(44, 44)),
                      icon: added
                          ? const _InCartHandbag(size: 24)
                          : opensDetails
                              ? const _HomeAngle(size: 20)
                              : SvgPicture.asset(
                                  'assets/handbag_plus/light-normal.svg',
                                  width: 24,
                                  height: 24,
                                  excludeFromSemantics: true,
                                  colorFilter: const ColorFilter.mode(
                                      Colors.white, BlendMode.srcIn)),
                      label: Text(label))
                  : opensDetails && !added
                      ? IconButton.filledTonal(
                          onPressed: action,
                          style: IconButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              foregroundColor: AppColors.brandLink,
                              backgroundColor: AppColors.brandBlueContainer),
                          icon: const _HomeAngle(size: 20))
                      : _HandbagPlusButton(onPressed: action, added: added));
        });
  }
}

class _HandbagPlusButton extends StatefulWidget {
  const _HandbagPlusButton({required this.onPressed, required this.added});

  final VoidCallback? onPressed;
  final bool added;

  @override
  State<_HandbagPlusButton> createState() => _HandbagPlusButtonState();
}

class _HandbagPlusButtonState extends State<_HandbagPlusButton> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light';
    return TextButton(
      statesController: _states,
      onPressed: widget.onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        backgroundColor: AppColors.brandBlueContainer,
      ),
      child: ValueListenableBuilder<Set<WidgetState>>(
        valueListenable: _states,
        builder: (_, states, __) {
          if (widget.added) {
            return const _InCartHandbag(size: 32);
          }
          final state = switch (states) {
            _ when widget.onPressed == null => 'disabled',
            _ when states.contains(WidgetState.pressed) => 'pressed',
            _ when states.contains(WidgetState.focused) => 'focus',
            _ when states.contains(WidgetState.hovered) => 'hover',
            _ => 'normal',
          };
          return SvgPicture.asset(
            'assets/handbag_plus/$theme-$state.svg',
            width: 32,
            height: 32,
            excludeFromSemantics: true,
          );
        },
      ),
    );
  }
}

class _HomePicker extends StatelessWidget {
  const _HomePicker(
      {required this.title, required this.count, required this.itemBuilder});
  final String title;
  final int count;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .62,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const LucideIcon(LucideGlyph.close)),
              ])),
          Expanded(
              child:
                  ListView.builder(itemCount: count, itemBuilder: itemBuilder)),
        ]),
      ));
}

class _HomeSupplierConversation extends StatefulWidget {
  const _HomeSupplierConversation({required this.supplier});
  final ImporterOption supplier;

  @override
  State<_HomeSupplierConversation> createState() =>
      _HomeSupplierConversationState();
}

class _HomeSupplierConversationState extends State<_HomeSupplierConversation> {
  late Future<String> _thread;

  @override
  void initState() {
    super.initState();
    _thread = _open();
  }

  Future<String> _open() =>
      StoreSupplierChatService.openOrCreate(importadorId: widget.supplier.id);

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _thread,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return StoreSupplierChatScreen(threadId: snapshot.data!);
          }
          return Scaffold(
            appBar: AppBar(title: Text(widget.supplier.businessName)),
            body: Center(
                child: snapshot.hasError
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('No pudimos abrir la consulta.'),
                        TextButton(
                            onPressed: () => setState(() => _thread = _open()),
                            child: const Text('Reintentar')),
                      ])
                    : const CircularProgressIndicator()),
          );
        },
      );
}

class _HomeRecentSection extends StatefulWidget {
  const _HomeRecentSection({required this.viewerId, required this.builder});
  final String viewerId;
  final Widget Function(List<PartModel>) builder;

  @override
  State<_HomeRecentSection> createState() => _HomeRecentSectionState();
}

class _HomeRecentSectionState extends State<_HomeRecentSection> {
  late Future<List<PartModel>> _items;

  void _reload() => setState(() => _items = _load());

  Future<List<PartModel>> _load() => CatalogService.fetchHomeProducts(
      RecentProductViews.forViewer(widget.viewerId));

  @override
  void initState() {
    super.initState();
    _items = _load();
    RecentProductViews.changes.addListener(_reload);
  }

  @override
  void didUpdateWidget(covariant _HomeRecentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerId != widget.viewerId) _items = _load();
  }

  @override
  void dispose() {
    RecentProductViews.changes.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PartModel>>(
        future: _items,
        builder: (_, snapshot) {
          final items = snapshot.data;
          if (items == null || items.isEmpty) return const SizedBox.shrink();
          return widget.builder(items);
        },
      );
}

const _homeSectionInset = 14.0;

class _HomePromotionCarousel extends StatefulWidget {
  const _HomePromotionCarousel(
      {required this.campaigns, required this.onCampaign});
  final List<PromoCampaignModel> campaigns;
  final ValueChanged<PromoCampaignModel> onCampaign;

  @override
  State<_HomePromotionCarousel> createState() => _HomePromotionCarouselState();
}

class _HomePromotionCarouselState extends State<_HomePromotionCarousel> {
  final _page = PageController(viewportFraction: .90);
  final _ratios = <String, double>{};
  ImageStream? _activeImage;
  ImageStreamListener? _activeListener;
  int _index = 0;

  String get _activeUrl =>
      widget.campaigns[_index.clamp(0, widget.campaigns.length - 1)]
          .imageUrlForWidth(400);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measureActiveImage();
  }

  @override
  void didUpdateWidget(covariant _HomePromotionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _index = _index.clamp(0, widget.campaigns.length - 1);
    _measureActiveImage();
  }

  void _measureActiveImage() {
    final url = _activeUrl;
    final stream =
        NetworkImage(url).resolve(createLocalImageConfiguration(context));
    if (_activeImage?.key == stream.key) return;
    _stopMeasuring();
    final listener = ImageStreamListener((image, synchronousCall) {
      final ratio = image.image.width / image.image.height;
      image.dispose();
      if (_ratios[url] == ratio || !mounted) return;
      if (synchronousCall) {
        _ratios[url] = ratio;
      } else {
        setState(() => _ratios[url] = ratio);
      }
    }, onError: (_, __) {});
    _activeImage = stream;
    _activeListener = listener;
    stream.addListener(listener);
  }

  void _stopMeasuring() {
    final listener = _activeListener;
    if (listener != null) _activeImage?.removeListener(listener);
  }

  @override
  void dispose() {
    _stopMeasuring();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.campaigns.length;
    final ratio = _ratios[_activeUrl] ?? 2.4;
    final cardFraction = count == 1 ? 1.0 : _page.viewportFraction;
    return Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        final endInset = count == 1 ? 0.0 : _homeSectionInset;
        final viewportWidth = constraints.maxWidth - endInset;
        final cardWidth = viewportWidth * cardFraction - endInset;
        return SizedBox(
          height: cardWidth / ratio,
          child: count == 1
              ? _promotionCard(widget.campaigns.single)
              : ClipRect(
                  clipper: const _PromotionCarouselClipper(),
                  child: Padding(
                    // Shorten the scroll viewport while keeping its paint clip
                    // at the screen edge, so the end gap only shows at rest.
                    padding: EdgeInsets.only(right: endInset),
                    child: PageView.builder(
                      controller: _page,
                      clipBehavior: Clip.none,
                      padEnds: false,
                      itemCount: count,
                      onPageChanged: (value) {
                        setState(() => _index = value);
                        _measureActiveImage();
                      },
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(left: _homeSectionInset),
                        child: _promotionCard(widget.campaigns[index]),
                      ),
                    ),
                  ),
                ),
        );
      }),
      if (count > 1)
        Wrap(alignment: WrapAlignment.center, children: [
          for (var index = 0; index < count; index++)
            Semantics(
                selected: index == _index.clamp(0, count - 1),
                child: InkWell(
                  onTap: () {
                    if (MediaQuery.disableAnimationsOf(context)) {
                      _page.jumpToPage(index);
                    } else {
                      _page.animateToPage(index,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Tooltip(
                      message: 'Tarjeta ${index + 1} de $count',
                      child: SizedBox(
                        width: 30,
                        height: 32,
                        child: Center(
                            child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          width: index == _index.clamp(0, count - 1) ? 20 : 8,
                          height: 7,
                          decoration: BoxDecoration(
                              color: index == _index.clamp(0, count - 1)
                                  ? AppColors.brandLink
                                  : AppColors.borderSubtle,
                              borderRadius: BorderRadius.circular(8)),
                        )),
                      )),
                )),
        ]),
    ]);
  }

  Widget _promotionCard(PromoCampaignModel campaign) {
    const radius = BorderRadius.all(Radius.circular(16));
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0xA6000000) : const Color(0x5C173757),
            offset: const Offset(0, 17),
            blurRadius: 24,
            spreadRadius: -3,
          ),
          BoxShadow(
            color: dark ? const Color(0x55000000) : const Color(0x30133254),
            offset: const Offset(0, 4),
            blurRadius: 9,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: _homeNavy,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: campaign.displayTitle ?? campaign.internalTitle,
          child: InkWell(
            onTap: () => widget.onCampaign(campaign),
            child: Image.network(
              campaign.imageUrlForWidth(400),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: LucideIcon(LucideGlyph.image, color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCardSnapPhysics extends ScrollPhysics {
  const _HomeCardSnapPhysics(this.itemExtent, this.itemCount, {super.parent});

  final double itemExtent;
  final int itemCount;

  @override
  _HomeCardSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _HomeCardSnapPhysics(itemExtent, itemCount,
          parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final start = position.minScrollExtent;
    final end = position.maxScrollExtent;
    // Both ends have the section inset. Split the extra centering space evenly.
    final centerShift = ((itemCount - 1) * itemExtent - (end - start)) / 2;
    final bias = (velocity * .08).clamp(-itemExtent * .2, itemExtent * .2);
    final projected = position.pixels + bias;
    var target = start;
    for (var i = 1; i < itemCount; i++) {
      final offset = i == itemCount - 1
          ? end
          : (start + i * itemExtent - centerShift).clamp(start, end);
      if ((offset - projected).abs() < (target - projected).abs()) {
        target = offset;
      }
    }
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    final settlingVelocity =
        (target - position.pixels) * velocity > 0 ? velocity : 0.0;
    return ScrollSpringSimulation(
        spring, position.pixels, target, settlingVelocity,
        tolerance: tolerance);
  }
}

class _PromotionCarouselClipper extends CustomClipper<Rect> {
  const _PromotionCarouselClipper();

  // Clip banners at the screen edges and let the shadow reach the dots.
  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, -6, size.width, size.height + 42);

  @override
  bool shouldReclip(covariant _PromotionCarouselClipper oldClipper) => false;
}

extension on _AliadoHomeDashboardState {
  Widget _mobile() {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
          fontFamily: iosChromeFontFallback.first,
          fontFamilyFallback: iosChromeFontFallback.sublist(1),
        ),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.background
            : const Color(0xFFF4F6F9),
        body: RefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: 82,
          child: FutureBuilder<AliadoHomeData>(
            future: _data,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return CustomScrollView(
                key: const PageStorageKey('aliado-inicio-movil'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _mobileHeader(),
                  if (snapshot.connectionState != ConnectionState.done &&
                      data == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (snapshot.hasError || (data?.errors.isNotEmpty ?? false))
                    _block(Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(snapshot.hasError
                            ? 'No pudimos cargar Inicio.'
                            : 'No pudimos cargar ${data!.errors.join(', ')}.'),
                        TextButton(
                            onPressed: _refresh,
                            child: const Text('Reintentar')),
                      ],
                    )),
                  if (data != null)
                    ..._mobileSections(data,
                        showTracking:
                            snapshot.connectionState == ConnectionState.done),
                  SliverToBoxAdapter(child: SizedBox(height: 16 + bottomInset)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _mobileHeader() => AliadoHomeHeader(
        identity: _mobileIdentity,
        search: _mobileSearch(),
        searchAction: _homeToolbarButton(
          label: 'Abrir búsqueda',
          onTap: _openHomeSearch,
          icon: LucideGlyph.search,
        ),
        actions: [
          ListenableBuilder(
            key: const ValueKey('home-cart'),
            listenable: CartService.instance,
            builder: (_, __) => _homeToolbarButton(
              label: 'Carrito',
              onTap: _cart,
              icon: LucideGlyph.handbag,
              count: CartService.instance.itemCount,
            ),
          ),
          const BcvRateBadge(
            key: ValueKey('home-bcv'),
            alwaysVisible: true,
            iconColor: Colors.white,
            size: Size(44, 44),
          ),
          if (widget.onMessagesTap != null || widget.onNotificationTap != null)
            KeyedSubtree(
              key: const ValueKey('home-inbox'),
              child: _homeToolbarButton(
                label: 'Bandeja',
                onTap: _openHomeInbox,
                icon: LucideGlyph.inbox,
                unread:
                    widget.unreadNotifications > 0 || widget.unreadMessages > 0,
              ),
            ),
        ],
      );

  Widget _homeToolbarButton({
    required String label,
    required VoidCallback onTap,
    required LucideGlyph icon,
    int count = 0,
    bool unread = false,
  }) =>
      Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: label,
          value:
              unread ? 'Con novedades' : (count > 0 ? '$count unidades' : null),
          child: IosPressable(
            onTap: onTap,
            radius: BorderRadius.circular(22),
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: ExcludeSemantics(
                  child: Badge(
                    isLabelVisible: unread || count > 0,
                    backgroundColor:
                        unread ? const Color(0xFFFFAA80) : _homeNavy,
                    smallSize: 8,
                    label: count > 0 ? Text(count > 9 ? '9+' : '$count') : null,
                    child: LucideIcon(icon, size: 21, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _openHomeInbox() async {
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Bandeja', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (widget.onMessagesTap != null)
                _inboxDestination(sheet, 'Mensajes', LucideGlyph.messageCircle,
                    widget.unreadMessages, widget.onMessagesTap!),
              if (widget.onNotificationTap != null)
                _inboxDestination(sheet, 'Notificaciones', LucideGlyph.bell,
                    widget.unreadNotifications, widget.onNotificationTap!),
            ]),
          ),
        ),
      ),
    );
    if (mounted) action?.call();
  }

  Widget _inboxDestination(BuildContext sheet, String label, LucideGlyph icon,
      int unread, VoidCallback action) {
    return ListTile(
      onTap: () => Navigator.pop(sheet, action),
      leading: LucideIcon(icon),
      title: Text(label),
      subtitle: unread > 0 ? Text('$unread sin leer') : null,
      trailing: const _HomeAngle(size: 16),
    );
  }

  Widget _mobileIdentity(bool compact) => Row(
        children: [
          Semantics(
            button: true,
            label: 'Abrir perfil',
            child: InkWell(
              onTap: MainShellTabController.navigateToProfileTab,
              customBorder: const CircleBorder(),
              child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFFFA344), width: 1.5)),
                  child: _HomeLogo(
                      path: widget.profile.logoStoragePath, size: 38)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.profile.businessName?.trim().isNotEmpty == true
                      ? widget.profile.businessName!.trim()
                      : 'Mi negocio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.32,
                      height: 1.12),
                ),
                if (!compact)
                  const Text('Tienda minorista',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFFE5EFFF), fontSize: 12)),
              ],
            ),
          ),
        ],
      );

  Future<void> _openHomeSearch() async {
    final openFilters = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Buscar repuestos',
                style: Theme.of(sheet).textTheme.titleMedium),
            const SizedBox(height: 10),
            _mobileSearch(
              autofocus: true,
              onSearch: () => Navigator.pop(sheet, false),
              onFilters: () => Navigator.pop(sheet, true),
            ),
          ]),
        ),
      ),
    );
    if (!mounted || openFilters == null) return;
    _searchCatalogWithFilters(openFilters);
  }

  void _searchCatalogWithFilters(bool openFilters) =>
      MainShellTabController.navigateToAliadoCatalog(
        filters: CatalogFilters(searchQuery: _search.text.trim()),
        openFilters: openFilters,
      );

  Widget _mobileSearch(
      {bool autofocus = false,
      VoidCallback? onSearch,
      VoidCallback? onFilters}) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted =
        dark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF64748B);
    final submit = onSearch ?? _searchCatalog;
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
      child: TextField(
        controller: _search,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => submit(),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Buscar repuestos, bujías, cauchos…',
          hintStyle: TextStyle(color: muted, fontSize: 14),
          prefixIcon: IconButton(
            tooltip: 'Buscar en el catálogo',
            onPressed: submit,
            icon: LucideIcon(LucideGlyph.search, size: 19, color: muted),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Filtros del catálogo',
              onPressed: onFilters ?? () => _searchCatalogWithFilters(true),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(44),
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFF245DE6),
              ),
              icon: const SizedBox.square(
                dimension: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF245DE6),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: LucideIcon(LucideGlyph.slidersHorizontal,
                        size: 17, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          filled: true,
          fillColor: dark ? theme.colorScheme.surface : Colors.white,
          border: outline,
          enabledBorder: outline,
          focusedBorder: outline.copyWith(
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _block(Widget child, {double top = 18, bool fullWidth = false}) {
    final inset = fullWidth ? 0.0 : _homeSectionInset;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(inset, top, inset, 0),
      sliver: SliverToBoxAdapter(child: child),
    );
  }

  List<Widget> _mobileSections(AliadoHomeData data,
      {required bool showTracking}) {
    final brands = <String, MapEntry<String, String>>{};
    for (final product in [
      ...data.newArrivals,
      ...data.buyAgain,
      ...data.bestSellers
    ]) {
      for (final entry
          in productCustomFieldValues(product.customFields).entries) {
        final key = entry.key.toLowerCase().replaceFirst('col_', '');
        if (!const {'marca', 'brand', 'marca_proveedor'}.contains(key)) {
          continue;
        }
        if (!parseAliadoVisibleCustomFieldKeys(product.customFields)
            .contains(entry.key)) continue;
        final value = product.customFields[entry.key];
        if (value is! String || value.trim().isEmpty) continue;
        brands.putIfAbsent(
            value.trim().toLowerCase(), () => MapEntry(entry.key, value));
      }
    }
    final campaigns = data.promotions
        .where((promo) => promo.isBanner && promo.hasDisplayCreative)
        .toList();
    return [
      if (campaigns.isNotEmpty) ...[
        _block(
          _homeHeading('Para tu negocio',
              action: campaigns.length > 1 ? 'Ver todas' : null,
              onAction: () => showAliadoActivePromotionsSheet(
                    context: context,
                    campaigns: campaigns,
                    onPromoCampaignSelected: _openHomeCampaign,
                  )),
          top: 10,
        ),
        _block(
            _HomePromotionCarousel(
              campaigns: campaigns,
              onCampaign: _openHomeCampaign,
            ),
            top: 0,
            fullWidth: campaigns.length > 1),
      ],
      if (data.categories.isNotEmpty)
        _block(
          top: campaigns.length > 1 ? 4 : 18,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _homeHeading(
                'Categorías',
                action: data.categories.length > 4 ||
                        data.categories
                            .any((group) => group.children.isNotEmpty)
                    ? 'Ver todas'
                    : null,
                showActionAngle: true,
                onAction: () => _categories(data),
              ),
              LayoutBuilder(builder: (context, bounds) {
                final count =
                    MediaQuery.textScalerOf(context).scale(13) > 19 ? 2 : 4;
                final width = (bounds.maxWidth - (count - 1) * 8) / count;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final group in data.categories.take(4))
                    SizedBox(
                        width: width,
                        child: _CategoryShortcut(
                          label: group.label,
                          illustrated: true,
                          onTap: () => _openCategory(group),
                        )),
                ]);
              }),
            ],
          ),
        ),
      if (brands.isNotEmpty)
        _block(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _homeHeading('Compra por marca',
                  action: 'Ver todas',
                  onAction: () => _showBrands(brands.values.toList())),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final brand in brands.values.take(12))
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: () =>
                              _catalog(CatalogFilters(brandField: brand)),
                          style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: Text(brand.value.trim(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        )),
                ]),
              ),
            ]),
            top: 8),
      if (showTracking && data.activeOrders > 0)
        _block(_homeStrip(
          icon: LucideGlyph.van,
          title: data.activeOrders == 1
              ? '1 pedido en curso'
              : '${data.activeOrders} pedidos en curso',
          action: 'Ver seguimiento',
          onTap: MainShellTabController.navigateToPedidosTab,
        )),
      if (data.buyAgain.isNotEmpty)
        _block(_homePanel(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _homeHeading('Compra de nuevo',
                action: data.buyAgain.length > 2 ? 'Ver más' : null,
                onAction: () =>
                    _showProducts('Compra de nuevo', data.buyAgain)),
            for (final (index, part) in data.buyAgain.take(2).indexed) ...[
              if (index > 0) Divider(height: 12, color: AppColors.borderSubtle),
              _compactProduct(part),
            ],
          ],
        )))
      else if (data.errors.isEmpty)
        _block(_homeStrip(
            icon: LucideGlyph.package,
            title: 'Tu próxima compra comienza aquí',
            action: 'Explorar catálogo',
            onTap: _catalog)),
      if (data.bestSellers.isNotEmpty)
        _block(
          _productSection(
            _homeHeading('Más vendidos',
                subtitle: 'Últimos 30 días',
                action: 'Ver todos',
                onAction: () =>
                    _showProducts('Más vendidos', data.bestSellers)),
            data.bestSellers,
            featured: true,
          ),
          fullWidth: true,
        ),
      if (data.newArrivals.isNotEmpty)
        _block(
          _productSection(
            _homeHeading('Novedades'),
            data.newArrivals.take(8),
          ),
          fullWidth: true,
        ),
      if (data.suppliers.isNotEmpty) ...[
        _block(_homePanel(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _homeHeading(
            'Tus proveedores',
            action: 'Ver tiendas',
            showActionAngle: true,
            onAction: () => _supplierPicker(data.suppliers, consult: false),
          ),
          Row(children: [
            for (final (index, supplier)
                in _featuredSuppliers(data).indexed) ...[
              if (index > 0)
                Container(width: 1, height: 54, color: AppColors.borderSubtle),
              Expanded(child: _supplierBadge(supplier)),
            ],
          ]),
        ]))),
        _block(_homeStrip(
            icon: LucideGlyph.messagesSquare,
            title: '¿No encuentras un repuesto?',
            subtitle: 'Consulta con un proveedor',
            action: 'Consultar',
            onTap: () => _supplierPicker(data.suppliers, consult: true))),
      ],
      _block(
        _HomeRecentSection(
          viewerId: widget.profile.id,
          builder: (items) =>
              _productSection(_homeHeading('Vistos recientemente'), items),
        ),
        fullWidth: true,
      ),
    ];
  }

  Iterable<ImporterOption> _featuredSuppliers(AliadoHomeData data) {
    final owned = data.buyAgain.map((part) => part.ownerId).toSet();
    return [
      ...data.suppliers.where((supplier) => owned.contains(supplier.id)),
      ...data.suppliers.where((supplier) => !owned.contains(supplier.id)),
    ].take(3);
  }

  void _openHomeCampaign(PromoCampaignModel campaign) {
    if (campaign.actionType == PromoCampaignModel.actionExternalUrl) {
      launchPromoCampaignExternalUrl(context, campaign);
    } else {
      _promotion(campaign);
    }
  }

  Widget _homeHeading(String title,
          {String? subtitle,
          String? action,
          bool showActionAngle = false,
          VoidCallback? onAction}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.45,
                          height: 1.15)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(color: AppColors.textSecondary)),
                ])),
            if (action != null)
              TextButton(
                  onPressed: onAction,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(action,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (showActionAngle) ...[
                      const SizedBox(width: 4),
                      const _HomeAngle(size: 16),
                    ],
                  ])),
          ]));

  Widget _homePanel(Widget child) => DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0708234C),
                  blurRadius: 12,
                  offset: Offset(0, 3)),
            ]),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6), child: child),
      );

  Widget _homeStrip(
          {required LucideGlyph icon,
          required String title,
          String? subtitle,
          required String action,
          required VoidCallback onTap}) =>
      Material(
        color: AppColors.brandBlueContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              LucideIcon(icon, color: AppColors.brandLink, size: 25),
              const SizedBox(width: 9),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, height: 1.2)),
                    if (subtitle != null)
                      Text(subtitle,
                          style: TextStyle(color: AppColors.textSecondary)),
                  ])),
              const SizedBox(width: 8),
              if (subtitle != null)
                Flexible(
                  child: DecoratedBox(
                    decoration: const ShapeDecoration(
                      color: _homeNavy,
                      shape: StadiumBorder(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                            child: Text(action,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700))),
                        const SizedBox(width: 4),
                        const _HomeAngle(size: 15, color: Colors.white),
                      ]),
                    ),
                  ),
                )
              else ...[
                Flexible(
                    child: Text(action,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            color: AppColors.brandLink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                _HomeAngle(size: 16, color: AppColors.brandLink),
              ],
            ]),
          ),
        ),
      );

  Widget _supplierBadge(ImporterOption supplier) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Semantics(
          label: supplier.businessName,
          button: true,
          child: Tooltip(
            message: supplier.businessName,
            excludeFromSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _openStore(supplier),
              child: Container(
                padding: const EdgeInsets.all(7),
                constraints: const BoxConstraints(minHeight: 84),
                decoration: BoxDecoration(
                    color: AppColors.card, shape: BoxShape.circle),
                child: ExcludeSemantics(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _HomeLogo(path: supplier.logoStoragePath, size: 40),
                  Text(supplier.businessName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11,
                          height: 1.1,
                          fontWeight: FontWeight.w800)),
                ])),
              ),
            ),
          ),
        ),
      );

  void _openPart(PartModel part) => CatalogRouteLock.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ProductDetailScreen(part: part)),
      );

  void _openStore(ImporterOption supplier) => CatalogRouteLock.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ImporterStoreProfileScreen(
                importerId: supplier.id, viewer: widget.profile)),
      );

  Future<void> _supplierPicker(List<ImporterOption> suppliers,
      {required bool consult}) async {
    final selected = await showModalBottomSheet<ImporterOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _HomePicker(
          title: consult ? 'Elige un proveedor' : 'Tiendas',
          count: suppliers.length,
          itemBuilder: (_, index) {
            final supplier = suppliers[index];
            return ListTile(
              leading: _HomeLogo(path: supplier.logoStoragePath, size: 38),
              title: Text(supplier.businessName),
              subtitle: Text(supplier.ubicacionLine),
              trailing: consult
                  ? const LucideIcon(LucideGlyph.messagesSquare)
                  : const _HomeAngle(),
              onTap: () => Navigator.pop(context, supplier),
            );
          }),
    );
    if (!mounted || selected == null) return;
    if (!consult) {
      _openStore(selected);
      return;
    }
    await CatalogRouteLock.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => _HomeSupplierConversation(supplier: selected)));
  }

  void _showBrands(List<MapEntry<String, String>> brands) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _HomePicker(
            title: 'Marcas',
            count: brands.length,
            itemBuilder: (_, index) => ListTile(
                  title: Text(brands[index].value.trim()),
                  trailing: const _HomeAngle(),
                  onTap: () {
                    Navigator.pop(context);
                    _catalog(CatalogFilters(brandField: brands[index]));
                  },
                )),
      );

  void _showProducts(String title, List<PartModel> products) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _HomePicker(
            title: title,
            count: products.length,
            itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.all(8),
                child: _compactProduct(products[index]))),
      );

  Widget _price(PartModel part) => CatalogProductPriceDisplay(
        usdColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.successGreen
            : const Color(0xFF00A859),
        listPriceUsd: part.precio,
        salePriceUsd: part.salePriceUsd,
        discountRules: part.discountRules,
        campaignDiscountPercent: part.activeCampaignDiscountPercent,
        ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
        catalogGrid: true,
        compact: true,
        showPromotionChips: false,
      );

  Widget _partCaption(PartModel part) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(part.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, height: 1.15)),
          if (part.ownerBusinessName?.isNotEmpty == true)
            Text(part.ownerBusinessName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      );

  Widget _compactProduct(PartModel part) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    return Row(children: [
      Expanded(
          child: InkWell(
        onTap: () => _openPart(part),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
                width: 60, height: 72, child: _HomeProductPhoto(part: part)),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _partCaption(part),
                  const SizedBox(height: 3),
                  Text(part.minOrderQtyLabelEs,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  if (largeText) _price(part),
                ])),
            if (!largeText) ...[
              const SizedBox(width: 6),
              SizedBox(width: 100, child: _price(part)),
            ],
          ]),
        ),
      )),
      _HomeAddButton(
          part: part,
          profile: widget.profile,
          onDetails: () => _openPart(part)),
    ]);
  }

  Widget _featuredProduct(PartModel part, double width) => _homePanel(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openPart(part),
            child: Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (part.category?.isNotEmpty == true)
                      Row(children: [
                        CatalogCategoryIcon(
                          art: CatalogCategoryArt.forLabel(part.category!),
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text(
                                catalogCategoryDisplayLabel(part.category!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary))),
                      ]),
                    const SizedBox(height: 4),
                    _partCaption(part),
                    const SizedBox(height: 8),
                    _price(part),
                    const SizedBox(height: 3),
                    Text(part.minOrderQtyLabelEs,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ]),
            ),
          )),
          SizedBox(
            width: (width * .41).clamp(96.0, 148.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => _openPart(part),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                        height: 100,
                        child:
                            _HomeProductPhoto(part: part, blendWithCard: true)),
                  ),
                  const SizedBox(height: 4),
                  _HomeAddButton(
                      part: part,
                      profile: widget.profile,
                      showLabel: true,
                      onDetails: () => _openPart(part)),
                ]),
          ),
        ]),
      );

  Widget _smallProduct(PartModel part, double width) => Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: () => _openPart(part),
            child: Row(children: [
              SizedBox(
                width: width * .39,
                height: 80,
                child: _HomeProductPhoto(part: part, blendWithCard: true),
              ),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 8, 6, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _partCaption(part),
                      const SizedBox(height: 4),
                      _price(part),
                      Text(part.minOrderQtyLabelEs,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ]),
              )),
            ])),
      );

  Widget _productSection(Widget heading, Iterable<PartModel> items,
          {bool featured = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _homeSectionInset),
          child: heading,
        ),
        _productStrip(items, featured: featured),
      ]);

  Widget _productStrip(Iterable<PartModel> items, {bool featured = false}) =>
      LayoutBuilder(builder: (context, bounds) {
        const gap = 8.0;
        final products = items.toList(growable: false);
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final contentWidth = bounds.maxWidth - 2 * _homeSectionInset;
        final width = featured
            ? (contentWidth * .88).clamp(230.0, 360.0)
            : (contentWidth * (scale > 1.35 ? .70 : .53)).clamp(162.0, 252.0);
        final extent = width + gap;
        final scrolls = products.length > 1 &&
            products.length * extent - gap > contentWidth;
        return SingleChildScrollView(
          key: ValueKey((extent, products.length)),
          scrollDirection: Axis.horizontal,
          physics:
              scrolls ? _HomeCardSnapPhysics(extent, products.length) : null,
          padding: const EdgeInsets.symmetric(horizontal: _homeSectionInset),
          child: IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                for (final (index, part) in products.indexed)
                  Padding(
                      padding: EdgeInsets.only(left: index == 0 ? 0 : gap),
                      child: SizedBox(
                          width: width,
                          child: featured
                              ? _featuredProduct(part, width)
                              : _smallProduct(part, width))),
              ])),
        );
      });
}
