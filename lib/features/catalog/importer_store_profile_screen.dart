import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/widgets/b2b_header_title.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_layout.dart';
import 'aliado_product_card.dart';
import 'mobile_supplier_chrome.dart';
import 'mobile_supplier_visuals.dart';
import 'package:motolink_pro_app/features/catalog/catalog_route_lock.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/catalog_taxonomy.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/favorite_heart_button.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_seals.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_share_link.dart';
import 'package:motolink_pro_app/features/catalog/share_qr_sheet.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/catalog/product_warranty_seal.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica_badge.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields_section.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/store_supplier_chat.dart';
import 'package:motolink_pro_app/features/catalog/variant_cart_picker_sheet.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Acceso a datos de la vitrina. En la app usa [SupabaseService]; en tests se inyecta.
class ImporterStoreCatalogSource {
  const ImporterStoreCatalogSource({
    required this.fetchProfile,
    required this.fetchCategories,
    required this.fetchParts,
    this.fetchCount,
    this.fetchVisibleProduct,
  });

  final Future<ImporterStoreProfile?> Function(String importerId) fetchProfile;
  final Future<List<String>> Function(String importerId) fetchCategories;
  final Future<List<PartModel>> Function({
    required int limit,
    required int offset,
    required CatalogFilters filters,
  }) fetchParts;

  /// Conteo exacto con los mismos filtros que [fetchParts].
  final Future<int> Function({required CatalogFilters filters})? fetchCount;
  final Future<PartModel?> Function({
    required String importerId,
    required String productId,
  })? fetchVisibleProduct;

  static ImporterStoreCatalogSource app() => ImporterStoreCatalogSource(
        fetchProfile: SupabaseService.fetchImporterStoreProfile,
        fetchCategories: SupabaseService.fetchImporterStoreCategories,
        fetchParts: ({
          required int limit,
          required int offset,
          required CatalogFilters filters,
        }) =>
            SupabaseService.fetchParts(
          limit: limit,
          offset: offset,
          filters: filters,
        ),
        fetchCount: ({required CatalogFilters filters}) =>
            SupabaseService.fetchProductsCount(filters: filters),
        fetchVisibleProduct: ({
          required String importerId,
          required String productId,
        }) =>
            SupabaseService.fetchVisibleImporterStoreProduct(
          importerId: importerId,
          productId: productId,
        ),
      );
}

/// Vitrina de un mayorista: ficha comercial y catálogo solo de ese negocio.
class ImporterStoreProfileScreen extends StatefulWidget {
  const ImporterStoreProfileScreen({
    super.key,
    required this.importerId,
    required this.viewer,
    this.initialCategory,
    this.catalogSource,
    this.onOpenSupplierChat,
  });

  final String importerId;
  final ProfileModel viewer;
  final String? initialCategory;
  final ImporterStoreCatalogSource? catalogSource;

  /// Sustituye la apertura real en pruebas. No recarga la vitrina.
  final Future<void> Function(BuildContext context)? onOpenSupplierChat;

  static Future<void> open(
    BuildContext context, {
    required String importerId,
    required ProfileModel viewer,
    String? initialCategory,
  }) {
    final id = importerId.trim();
    if (id.isEmpty) return Future<void>.value();
    return CatalogRouteLock.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ImporterStoreProfileScreen(
          importerId: id,
          viewer: viewer,
          initialCategory: initialCategory,
        ),
      ),
    );
  }

  @override
  State<ImporterStoreProfileScreen> createState() =>
      _ImporterStoreProfileScreenState();
}

class _ImporterStoreProfileScreenState
    extends State<ImporterStoreProfileScreen> {
  final _scrollController = ScrollController();
  final _mobileSearch = TextEditingController();
  Timer? _searchDebounce;
  late final ImporterStoreCatalogSource _source;
  ImporterStoreProfile? _profile;
  List<String> _categories = const [];
  final List<PartModel> _parts = [];
  bool _loadingProfile = true;
  bool _notFound = false;
  String? _error;
  bool _loadingMore = false;
  bool _hasMore = true;
  int? _matchingTotal;
  String? _selectedCategory;
  bool _desktopStore = false;
  int _viewPage = 0;
  int _viewPageSize = listPageSizeOptions.first;
  int _loadGen = 0;

  int get _pagerTotal =>
      listPagerTotal(loaded: _parts.length, matching: _matchingTotal);

  List<AliadoCatalogCategoryGroup> _webFamilies() => [
        for (final family in webStoreCategoryFamilies(_categories))
          if (family.hasInventory) family,
      ];

  CatalogFilters get _filters {
    final values = catalogValuesForSelection(
      _desktopStore ? _webFamilies() : catalogCategoryFamilies(_categories),
      _selectedCategory,
    );
    return CatalogFilters.importerStore(
      importerId: widget.importerId,
      category: values.length == 1 ? values.single : null,
    ).copyWith(
        categoryAnyOf: values.length > 1 ? values : const [],
        searchQuery: _mobileSearch.text.trim());
  }

  @override
  void initState() {
    super.initState();
    _mobileSearch.addListener(_queueMobileSearch);
    _source = widget.catalogSource ?? ImporterStoreCatalogSource.app();
    final initial = widget.initialCategory?.trim();
    if (initial != null && initial.isNotEmpty) {
      _selectedCategory = initial;
    }
    _loadProfile();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mobileSearch.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _queueMobileSearch() {
    _searchDebounce?.cancel();
    _loadGen++;
    setState(() {
      _parts.clear();
      _matchingTotal = null;
      _loadingMore = true;
      _error = null;
    });
    _searchDebounce =
        Timer(const Duration(milliseconds: 320), () => _loadMore(reset: true));
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _error = null;
      _notFound = false;
    });
    try {
      final profile = await _source.fetchProfile(widget.importerId);
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _profile = null;
          _notFound = true;
          _loadingProfile = false;
        });
        return;
      }
      List<String> cats = const [];
      try {
        cats = await _source.fetchCategories(widget.importerId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _categories = cats;
        _loadingProfile = false;
        _parts.clear();
        _matchingTotal = null;
        _hasMore = true;
        _viewPage = 0;
      });
      await _loadMore(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (reset) _searchDebounce?.cancel();
    if (!reset && (_loadingMore || !_hasMore)) return;
    final gen = ++_loadGen;
    setState(() => _loadingMore = true);
    try {
      if (reset) {
        _error = null;
        _parts.clear();
        _matchingTotal = null;
        _hasMore = true;
        _viewPage = 0;
      }
      final countFn = _source.fetchCount;
      final filters = _filters;
      final countFuture = reset && countFn != null
          ? countFn(filters: filters)
              .then<int?>((value) => value)
              .catchError((_) => null)
          : null;
      final page = await _source.fetchParts(
        limit: _viewPageSize,
        offset: _parts.length,
        filters: filters,
      );
      if (!mounted || gen != _loadGen) return;
      final kept = constrainCatalogPartsToFilters(page, filters);
      int? matching = _matchingTotal;
      if (countFuture != null) {
        matching = await countFuture;
        if (!mounted || gen != _loadGen) return;
      }
      final loaded = _parts.length + kept.length;
      setState(() {
        if (reset) _matchingTotal = matching;
        _parts.addAll(kept);
        _hasMore = listPagerHasMore(
          loaded: loaded,
          batchLength: page.length,
          fetchSize: _viewPageSize,
          matching: reset ? matching : _matchingTotal,
        );
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loadingMore = false;
        if (_parts.isEmpty) _error = e.toString();
      });
    }
  }

  Future<void> _openViewPage(int index) async {
    final need = (index + 1) * _viewPageSize;
    while (mounted && _parts.length < need && _hasMore) {
      final before = _parts.length;
      await _loadMore();
      if (!mounted || _parts.length == before) break;
    }
    if (!mounted) return;
    setState(() {
      _viewPage = clampListPageIndex(
        pageIndex: index,
        total: _pagerTotal,
        pageSize: _viewPageSize,
      );
    });
  }

  void _selectCategory(String? category) {
    final next = category?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (normalized == _selectedCategory) return;
    setState(() {
      _selectedCategory = normalized;
      _viewPage = 0;
    });
    _loadMore(reset: true);
  }

  Future<void> _openProduct(PartModel part) async {
    if (!CatalogRouteLock.tryHold()) return;
    var handedOff = false;
    try {
      handedOff = await _pushProduct(part);
    } finally {
      if (!handedOff) CatalogRouteLock.release();
    }
  }

  Future<bool> _pushProduct(PartModel part) async {
    if (!catalogPartBelongsToImporterStore(
      importerId: widget.importerId,
      ownerId: part.ownerId,
      isActive: part.isActive,
    )) {
      final checked = await (_source.fetchVisibleProduct ??
          SupabaseService.fetchVisibleImporterStoreProduct)(
        importerId: widget.importerId,
        productId: part.id,
      );
      if (!mounted) return false;
      if (checked == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ese producto no pertenece a este mayorista.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      await CatalogRouteLock.pushHeld(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(part: checked),
        ),
      );
      return true;
    }
    await CatalogRouteLock.pushHeld(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(part: part),
      ),
    );
    return true;
  }

  bool get _canMessageSupplier => showStoreSupplierChatButton(
        viewerRole: widget.viewer.role,
        viewerId: widget.viewer.id,
        importerId: widget.importerId,
      );

  Future<void> _openSupplierChat() async {
    final custom = widget.onOpenSupplierChat;
    if (custom != null) {
      await custom(context);
      return;
    }
    try {
      final threadId = await StoreSupplierChatService.openOrCreate(
        importadorId: widget.importerId,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StoreSupplierChatScreen(threadId: threadId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el mensaje: $e')),
      );
    }
  }

  Future<void> _openMaps(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _desktopStore =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = _desktopStore;
    final showNavigation = !desktop &&
        widget.viewer.isAliado &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    final hPad = desktop ? 40.0 : AliadoCatalogLayout.horizontalPadding(width);
    const maxW = AppBreakpoints.adminContentMaxWidth;
    final theme = B2BThemeExtension.of(context);

    return Scaffold(
      backgroundColor: desktop ? theme.background : AppColors.background,
      extendBody: showNavigation,
      appBar: !desktop
          ? mobileSupplierAppBar(context,
              title: _profile?.displayName ?? 'Mayorista',
              viewer: widget.viewer,
              brandedToolbarHeight: B2bHeaderTitle.singleLineToolbarHeight(
                context,
                titleFontSize: supplierHeaderTitleSize,
              ),
              actions: [
                  IconButton(
                      tooltip: 'Compartir QR',
                      onPressed: () => showShareQrSheet(context,
                          title: _profile?.displayName ?? 'Vitrina',
                          url: ImporterStoreShareLink.urlFor(widget.importerId),
                          subtitle: 'Vitrina del proveedor'),
                      icon: const Icon(Icons.qr_code_2))
                ])
          : AppBar(
              backgroundColor: desktop ? theme.surfaceCard : null,
              foregroundColor: desktop ? theme.textPrimary : null,
              surfaceTintColor: desktop ? theme.surfaceCard : null,
              elevation: desktop ? 0 : null,
              title: Text(
                _profile?.displayName ?? 'Mayorista',
                style: desktop
                    ? TextStyle(
                        color: theme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      )
                    : null,
              ),
              actions: [
                IconButton(
                  tooltip: 'Compartir QR',
                  onPressed: () => showShareQrSheet(
                    context,
                    title: _profile?.displayName ?? 'Vitrina',
                    url: ImporterStoreShareLink.urlFor(widget.importerId),
                    subtitle: 'Vitrina del proveedor',
                  ),
                  icon: const Icon(Icons.qr_code_2),
                ),
                if (_profile != null && _canMessageSupplier)
                  IconButton(
                    key: const Key('store-supplier-chat'),
                    tooltip: 'Mensaje al proveedor',
                    onPressed: _openSupplierChat,
                    icon: const LucideIcon(LucideGlyph.messageCircle),
                  ),
              ],
            ),
      bottomNavigationBar:
          showNavigation ? const SupplierMobileNavigation() : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxW),
          child: Builder(
              builder: (context) => _body(hPad,
                  desktop: desktop,
                  navigationInset: showNavigation
                      ? MediaQuery.paddingOf(context).bottom
                      : 0)),
        ),
      ),
    );
  }

  Widget _body(double hPad,
      {required bool desktop, required double navigationInset}) {
    if (_loadingProfile) {
      return const Center(
        key: Key('importer-store-loading'),
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_notFound) {
      return Center(
        key: const Key('importer-store-not-found'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No encontramos este mayorista.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ),
      );
    }
    if (_error != null && _profile == null) {
      return Center(
        key: const Key('importer-store-error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudo cargar el perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadProfile,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;
    final visibleParts = sliceListPage(
      items: _parts,
      pageIndex: _viewPage,
      pageSize: _viewPageSize,
    );
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, desktop ? 20 : 12, hPad, 0),
          sliver: SliverToBoxAdapter(
            child: desktop ? _webHeader(profile) : _header(profile),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              hPad, desktop ? 22 : 12, hPad, desktop ? 16 : 8),
          sliver: SliverToBoxAdapter(
            child: desktop
                ? Column(children: [
                    Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: _storeSearchField())),
                    const SizedBox(height: 12),
                    _webCategoryChips(),
                  ])
                : _categoryChips(),
          ),
        ),
        if (_error != null && _parts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No se pudo cargar el catálogo.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _loadMore(reset: true),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          )
        else if (!_loadingMore && _parts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              key: const Key('importer-store-empty'),
              child: Text(
                _mobileSearch.text.trim().isNotEmpty
                    ? 'No hay productos que coincidan con tu búsqueda.'
                    : _selectedCategory == null
                        ? 'Este mayorista aún no tiene productos en vitrina.'
                        : 'No hay productos en esta categoría.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, gridConstraints) {
                  Widget cardAt(BuildContext context, int index) {
                    final part = visibleParts[index];
                    return desktop
                        ? _WebStoreProductCard(
                            part: part,
                            profile: widget.viewer,
                            showHeart: widget.viewer.isAliado,
                            onTap: () => _openProduct(part),
                          )
                        : AliadoProductCard(
                            part: part,
                            profile: widget.viewer,
                            compact: true,
                            showSupplier: false,
                            adaptiveColors: true,
                            storefront: true,
                            onTap: () => _openProduct(part),
                          );
                  }

                  if (desktop) {
                    return _WebStoreCardGrid(
                      maxWidth: gridConstraints.maxWidth,
                      itemCount: visibleParts.length,
                      itemBuilder: cardAt,
                    );
                  }
                  return _MobileStoreCardGrid(
                    maxWidth: gridConstraints.maxWidth,
                    itemCount: visibleParts.length,
                    itemBuilder: cardAt,
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
            sliver: SliverToBoxAdapter(
              child: ListPageBar(
                total: _pagerTotal,
                hasMore: _hasMore,
                pageIndex: _viewPage,
                pageSize: _viewPageSize,
                alwaysShow: true,
                onPageIndex: (index) {
                  _openViewPage(index);
                },
                onPageSize: (size) {
                  setState(() {
                    _viewPageSize = size;
                    _viewPage = 0;
                  });
                  if (_parts.length < size && _hasMore) {
                    _openViewPage(0);
                  }
                },
              ),
            ),
          ),
        ],
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ),
          ),
        if (navigationInset > 0)
          SliverToBoxAdapter(child: SizedBox(height: navigationInset)),
      ],
    );
  }

  Widget _header(ImporterStoreProfile profile) {
    final colors = Theme.of(context).colorScheme;
    final maps = profile.fiscalMapsUrl?.trim() ?? '';
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final categories = _categories
        .map(categoryFamily)
        .toSet()
        .take(3)
        .map(catalogCategoryDisplayLabel)
        .join(' · ');
    final details = <Widget>[
      if ((profile.direccion ?? '').trim().isNotEmpty)
        _StoreDetailRow(
            icon: Icons.place_outlined, text: profile.direccion!.trim()),
      if ((profile.rif ?? '').trim().isNotEmpty)
        _StoreDetailRow(icon: Icons.badge_outlined, text: 'RIF ${profile.rif}'),
      if ((profile.phone ?? '').trim().isNotEmpty)
        _StoreDetailRow(
            icon: Icons.phone_outlined,
            text: profile.phone!,
            onTap: () => _openPhone(profile.phone!)),
    ];
    final divider = Divider(height: 15, color: supplierOutlineColor(context));
    final consult = OutlinedButton.icon(
        key: const Key('store-supplier-chat'),
        onPressed: _openSupplierChat,
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: colors.primary,
            backgroundColor: colors.surface,
            side: BorderSide(color: colors.primary, width: 1.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            textStyle: TextStyle(
                fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        icon: const LucideIcon(LucideGlyph.messageCircle, size: 20),
        label: const Text('Consultar proveedor'));
    final location = TextButton.icon(
        onPressed: () => _openMaps(maps),
        style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            textStyle: TextStyle(
                fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.place_outlined, size: 21),
        label: const Text('Ver ubicación'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Material(
          color: supplierPanelColor(context),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mobileSupplierLogo(context,
                              path: profile.logoStoragePath,
                              size: scale > 1.3 ? 66 : 80),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(profile.displayName,
                                    style: TextStyle(
                                        fontSize: 22,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800,
                                        color: colors.onSurface)),
                                if (profile.locationLine.isNotEmpty)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.location_on_outlined,
                                                size: 18,
                                                color: colors.onSurfaceVariant),
                                            const SizedBox(width: 3),
                                            Expanded(
                                                child: Text(
                                                    profile.locationLine,
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        height: 1.2,
                                                        color:
                                                            colors.onSurface))),
                                          ])),
                                const SizedBox(height: 5),
                                SupplierRating(
                                    average: profile.ratingAvg,
                                    count: profile.ratingCount),
                                if (profile.isCatalogVerified ||
                                    profile.isCatalogFeatured)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: ImporterCatalogSealsRow(
                                          verified: profile.isCatalogVerified,
                                          featured: profile.isCatalogFeatured,
                                          compact: true)),
                              ])),
                        ]),
                    if (categories.isNotEmpty) ...[
                      divider,
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.storefront_outlined,
                                size: 21, color: colors.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(categories,
                                    style: TextStyle(
                                        fontSize: 14,
                                        height: 1.2,
                                        color: colors.onSurface))),
                          ]),
                    ],
                    if (profile.hasMinOrder)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(profile.minOrderLabelEs,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700))),
                    if (profile.pagoMetodoLabelsEs.isNotEmpty) ...[
                      divider,
                      Text(
                          profile.pagoSoloDivisas
                              ? 'Pago en divisas'
                              : 'Métodos de pago',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 7, runSpacing: 6, children: [
                        for (final method in profile.pagoMetodoLabelsEs)
                          SupplierCategoryPill(label: method),
                      ]),
                    ],
                    if (details.isNotEmpty) ...[
                      divider,
                      Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                              key: const Key('store-commercial-details'),
                              tilePadding: EdgeInsets.zero,
                              childrenPadding:
                                  const EdgeInsets.only(bottom: 10),
                              visualDensity: VisualDensity.compact,
                              title: const Text('Datos y ubicación',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              leading: const Icon(Icons.info_outline, size: 20),
                              children: details)),
                    ] else
                      const SizedBox(height: 12),
                  ]))),
      if (_canMessageSupplier || maps.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: LayoutBuilder(builder: (context, constraints) {
              if (_canMessageSupplier &&
                  maps.isNotEmpty &&
                  constraints.maxWidth >= 340 &&
                  scale <= 1.2) {
                return Row(children: [
                  Expanded(flex: 6, child: consult),
                  const SizedBox(width: 8),
                  Expanded(flex: 4, child: location),
                ]);
              }
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_canMessageSupplier) consult,
                    if (maps.isNotEmpty)
                      Align(alignment: Alignment.centerLeft, child: location),
                  ]);
            })),
    ]);
  }

  Future<void> _openPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Widget _storeSearchField() => TextField(
        key: const Key('store-product-search'),
        controller: _mobileSearch,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          _searchDebounce?.cancel();
          _loadMore(reset: true);
        },
        decoration: InputDecoration(
            hintText: 'Buscar en esta tienda…',
            hintStyle: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            prefixIcon: const Center(
                widthFactor: 1,
                heightFactor: 1,
                child: LucideIcon(LucideGlyph.search, size: 19)),
            suffixIcon: _mobileSearch.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: _mobileSearch.clear,
                    icon: const Icon(Icons.close)),
            filled: true,
            fillColor: AppColors.card,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: supplierOutlineColor(context))),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      );
  Widget _categoryChips() {
    final families = catalogCategoryFamilies(_categories);
    final selected = canonicalCatalogCategory(_selectedCategory);
    final family = selected == null ? null : categoryFamily(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catálogo de ${_profile?.displayName ?? 'la tienda'}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _storeSearchField(),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SupplierFilterChip(
                  label: 'Todos',
                  selected: _selectedCategory == null,
                  onSelected: (_) => _selectCategory(null),
                ),
              ),
              for (final group in families)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SupplierFilterChip(
                    label: catalogCategoryDisplayLabel(group.label),
                    selected: family == group.label,
                    onSelected: (_) => _selectCategory(group.label),
                  ),
                ),
            ],
          ),
        ),
        for (final group in families)
          if (group.label == family && group.children.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                SupplierFilterChip(
                  label: 'Toda la categoría',
                  selected: selected == group.label,
                  onSelected: (_) => _selectCategory(group.label),
                ),
                for (final child in group.children)
                  SupplierFilterChip(
                    label: categoryLeaf(child.label),
                    selected: selected == child.label,
                    onSelected: (_) => _selectCategory(child.label),
                  ),
              ],
            ),
      ],
    );
  }

  Widget _webHeader(ImporterStoreProfile profile) {
    final theme = B2BThemeExtension.of(context);
    final rating = profile.ratingAvg;
    final count = profile.ratingCount ?? 0;
    final metodos = profile.pagoMetodoLabelsEs;
    final address = profile.direccion?.trim() ?? '';
    final rif = profile.rif?.trim() ?? '';
    final phone = profile.phone?.trim() ?? '';
    final maps = profile.fiscalMapsUrl?.trim() ?? '';
    final logo = profile.logoStoragePath?.trim() ?? '';
    final showRating = rating != null && count > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(color: theme.brand, child: const SizedBox(height: 3)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ImporterCatalogLogo(storagePath: logo, size: 72),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                color: theme.textPrimary,
                              ),
                            ),
                            if (profile.locationLine.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                profile.locationLine,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textSecondary,
                                ),
                              ),
                            ],
                            if (profile.isCatalogVerified ||
                                profile.isCatalogFeatured) ...[
                              const SizedBox(height: 10),
                              ImporterCatalogSealsRow(
                                verified: profile.isCatalogVerified,
                                featured: profile.isCatalogFeatured,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (showRating || profile.hasMinOrder) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (showRating)
                          _WebFactPill(
                            glyph: LucideGlyph.star,
                            label:
                                '${rating.toStringAsFixed(1)} · $count valoración${count == 1 ? '' : 'es'}',
                            background: theme.warningBg,
                            foreground: theme.warningFg,
                          ),
                        if (profile.hasMinOrder)
                          _WebFactPill(
                            glyph: LucideGlyph.package,
                            label: profile.minOrderLabelEs,
                            background: theme.surfaceSubtle,
                            foreground: theme.textPrimary,
                            border: theme.borderSubtle,
                          ),
                      ],
                    ),
                  ],
                  if (address.isNotEmpty ||
                      rif.isNotEmpty ||
                      phone.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, thickness: 1, color: theme.borderSubtle),
                    const SizedBox(height: 14),
                    if (address.isNotEmpty)
                      _WebMetaLine(
                        glyph: LucideGlyph.building2,
                        text: address,
                      ),
                    if (rif.isNotEmpty)
                      _WebMetaLine(
                        glyph: LucideGlyph.fileText,
                        text: 'RIF $rif',
                      ),
                    if (phone.isNotEmpty)
                      _WebMetaLine(
                        glyph: LucideGlyph.smartphone,
                        text: phone,
                        onTap: () => _openPhone(phone),
                      ),
                  ],
                  if (metodos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        LucideIcon(
                          LucideGlyph.creditCard,
                          size: 15,
                          color: theme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          profile.pagoSoloDivisas
                              ? 'Pago en divisas'
                              : 'Métodos de pago',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final metodo in metodos)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.brandContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              metodo,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.brand,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (maps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.brand,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _openMaps(maps),
                        icon: LucideIcon(
                          LucideGlyph.landmark,
                          size: 16,
                          color: theme.brand,
                        ),
                        label: const Text('Ver ubicación'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webCategoryChips() {
    final theme = B2BThemeExtension.of(context);
    final families = _webFamilies();
    final selected = canonicalCatalogCategory(_selectedCategory);
    final family = selected == null ? null : categoryFamily(selected);
    AliadoCatalogCategoryGroup? openGroup;
    for (final group in families) {
      if (group.label == family && group.children.isNotEmpty) {
        openGroup = group;
      }
    }
    final opened = openGroup;
    final children = [
      for (final child
          in opened?.children ?? const <AliadoCatalogCategoryGroup>[])
        if (child.hasInventory) child,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.center,
          child: Text(
            'Catálogo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _WebFilterChip(
              label: 'Todos',
              selected: _selectedCategory == null,
              onSelected: (_) => _selectCategory(null),
            ),
            for (final group in families)
              _WebFilterChip(
                label: catalogCategoryDisplayLabel(group.label),
                selected: family == group.label,
                onSelected: (_) => _selectCategory(group.label),
              ),
          ],
        ),
        if (opened != null && children.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _WebFilterChip(
                label: 'Toda la categoría',
                selected: selected == opened.label,
                onSelected: (_) => _selectCategory(opened.label),
              ),
              for (final child in children)
                _WebFilterChip(
                  label: categoryLeaf(child.label),
                  selected: selected == child.label,
                  onSelected: (_) => _selectCategory(child.label),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Filas de igual alto; el texto ampliado usa una columna completa.
class _MobileStoreCardGrid extends StatelessWidget {
  const _MobileStoreCardGrid(
      {required this.maxWidth,
      required this.itemCount,
      required this.itemBuilder});
  final double maxWidth;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final columns =
        scale > 1.2 ? 1 : AliadoCatalogLayout.crossAxisCount(maxWidth);
    const spacing = 10.0;
    return Column(children: [
      for (var row = 0; row < itemCount; row += columns) ...[
        if (row > 0) const SizedBox(height: spacing),
        IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var column = 0; column < columns; column++) ...[
            if (column > 0) const SizedBox(width: spacing),
            Expanded(
                child: row + column < itemCount
                    ? itemBuilder(context, row + column)
                    : const SizedBox.shrink()),
          ],
        ])),
      ],
    ]);
  }
}

class _StoreDetailRow extends StatelessWidget {
  const _StoreDetailRow({
    required this.icon,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color:
                    onTap == null ? AppColors.textSecondary : AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _WebFactPill extends StatelessWidget {
  const _WebFactPill({
    required this.glyph,
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  final LucideGlyph glyph;
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LucideIcon(glyph, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebMetaLine extends StatelessWidget {
  const _WebMetaLine({
    required this.glyph,
    required this.text,
    this.onTap,
  });

  final LucideGlyph glyph;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final tappable = onTap != null;
    final color = tappable ? theme.brand : theme.textSecondary;
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LucideIcon(glyph, size: 16, color: theme.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
    if (!tappable) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

class _WebFilterChip extends StatefulWidget {
  const _WebFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  State<_WebFilterChip> createState() => _WebFilterChipState();
}

class _WebFilterChipState extends State<_WebFilterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final selected = widget.selected;
    final background = selected
        ? theme.brand
        : (_hover ? theme.brandContainer : theme.surfaceCard);
    final foreground = selected
        ? Theme.of(context).colorScheme.onPrimary
        : (_hover ? theme.brand : theme.textPrimary);
    final border = selected || _hover ? theme.brand : theme.borderStrong;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: ChoiceChip(
        label: Text(widget.label),
        selected: selected,
        showCheckmark: false,
        onSelected: widget.onSelected,
        selectedColor: background,
        backgroundColor: background,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _WebStoreProductCard extends StatefulWidget {
  const _WebStoreProductCard({
    required this.part,
    required this.profile,
    required this.onTap,
    required this.showHeart,
  });

  final PartModel part;
  final ProfileModel profile;
  final VoidCallback onTap;
  final bool showHeart;

  @override
  State<_WebStoreProductCard> createState() => _WebStoreProductCardState();
}

class _WebStoreProductCardState extends State<_WebStoreProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final part = widget.part;
    final cover = part.coverImageUrl;
    final radius = BorderRadius.circular(16);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: theme.surfaceCard,
          borderRadius: radius,
          border: Border.all(
            color: _hover ? theme.brand : theme.borderSubtle,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.textPrimary.withOpacity(_hover ? 0.08 : 0.04),
              blurRadius: _hover ? 16 : 8,
              offset: Offset(0, _hover ? 8 : 2),
            ),
          ],
        ),
        child: Material(
          color: theme.surfaceCard,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          cover != null && cover.isNotEmpty
                              ? Image.network(
                                  cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _WebStoreImagePlaceholder(theme: theme),
                                )
                              : _WebStoreImagePlaceholder(theme: theme),
                          if (part.hasWarranty)
                            const Positioned(
                              top: 6,
                              left: 6,
                              child: ProductWarrantySeal(compact: true),
                            ),
                          if (widget.showHeart)
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: FavoriteHeartButton(
                                productId: part.id,
                                compact: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        part.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        categoryLeaf(
                          catalogCategoryDisplayLabel(
                            classifyCatalogProduct(
                                    part.category, part.nombre) ??
                                (part.category ?? ''),
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.brand,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CatalogProductPriceDisplay(
                        listPriceUsd: part.precio,
                        salePriceUsd: part.salePriceUsd,
                        quantity: part.minOrderQtyEffective,
                        ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                        discountRules: part.discountRules,
                        campaignDiscountPercent:
                            part.activeCampaignDiscountPercent,
                        catalogGrid: true,
                        showPromotionChips: false,
                        usdColor: theme.successFg,
                        refColor: theme.textPrimary,
                        bsColor: theme.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: EnvioPoliticaBadge(
                          tipo: part.ownerEnvioTipo,
                          compact: true,
                        ),
                      ),
                      if (EnvioPolitica.muestraBadge(part.ownerEnvioTipo))
                        const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${part.stockForSale} en stock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.successFg,
                              ),
                            ),
                            TextSpan(
                              text: ' · ${part.minOrderQtyLabelEs}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (productCustomFieldsDisplayEntries(
                        part.customFields,
                        aliadoView: true,
                      ).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ProductCustomFieldsAliadoChips(
                          customFields: part.customFields,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _WebStoreCartButton(
                        part: part,
                        profile: widget.profile,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebStoreCartButton extends StatelessWidget {
  const _WebStoreCartButton({
    required this.part,
    required this.profile,
  });

  final PartModel part;
  final ProfileModel profile;

  Future<void> _add(BuildContext context, CartService cart) async {
    if (part.variantChoices.isNotEmpty) {
      await showVariantCartPickerSheet(
        context: context,
        part: part,
        profile: profile,
        cart: cart,
      );
      return;
    }
    final added = CartProductActions.addMinimum(
      part: part,
      profile: profile,
      cart: cart,
    );
    if (added < 1 || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Agregado al carrito: ${part.nombre} · $added uds.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final cart = CartService.instance;
        final blocked = CartProductActions.blockReason(
          part: part,
          profile: profile,
          cart: cart,
        );
        final line = CartProductActions.lineFor(part, cart);
        final inCart = line != null;
        final minimum = part.minOrderQtyEffective;
        final label = inCart
            ? 'En el carrito · ${line.quantity}'
            : blocked != null
                ? 'No disponible'
                : 'Agregar al carrito';
        final background = inCart ? theme.successBg : theme.brand;
        final foreground = inCart ? theme.successFg : onBrand;
        final hint = blocked ??
            (inCart
                ? '${line.quantity} uds. en el carrito. Mínimo $minimum.'
                : 'Agrega $minimum uds., el mínimo de este producto.');
        return Tooltip(
          message: hint,
          child: FilledButton.icon(
            onPressed:
                blocked != null || inCart ? null : () => _add(context, cart),
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: background,
              disabledForegroundColor: foreground,
              minimumSize: const Size.fromHeight(40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: LucideIcon(
              inCart ? LucideGlyph.circleCheck : LucideGlyph.shoppingCart,
              size: 16,
              color: foreground,
            ),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

/// Grilla compacta de la vitrina web. La foto queda baja para dejar
/// nombre, categoría y USD / REF / Bs dentro de la ficha.
class _WebStoreCardGrid extends StatelessWidget {
  const _WebStoreCardGrid({
    required this.maxWidth,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double maxWidth;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  static const imageHeight = 96.0;
  static const bodyHeight = 276.0;
  static const spacing = 12.0;

  static int columnsFor(double width) {
    if (width >= 1280) return 5;
    if (width >= 1000) return 4;
    return 3;
  }

  static double childAspectRatio(double tileWidth) {
    final width = tileWidth <= 0 ? 1.0 : tileWidth;
    return width / (imageHeight + bodyHeight);
  }

  @override
  Widget build(BuildContext context) {
    final cols = columnsFor(maxWidth);
    final tileWidth =
        cols <= 1 ? maxWidth : (maxWidth - spacing * (cols - 1)) / cols;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: childAspectRatio(tileWidth),
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

class _WebStoreImagePlaceholder extends StatelessWidget {
  const _WebStoreImagePlaceholder({required this.theme});

  final B2BThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: theme.surfaceSubtle,
      child: Center(
        child: LucideIcon(
          LucideGlyph.image,
          size: 28,
          color: theme.textMuted,
        ),
      ),
    );
  }
}
