import 'package:flutter/material.dart';

import 'aliado_catalog_categories.dart';
import 'catalog_taxonomy.dart';
import 'aliado_catalog_filters_draft.dart';
import 'aliado_catalog_quick_filters.dart';
import 'aliado_catalog_toolbar.dart';
import 'aliado_product_card.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'catalog_filters.dart';
import 'catalog_grid_skeleton.dart';
import 'catalog_route_lock.dart';
import 'catalog_sort_mode.dart';
import 'promo_campaign_model.dart';
import 'part_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/cart/catalog_cart_bar.dart';
import 'package:motolink_pro_app/features/profile/geolocator_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/admin/admin_catalog_coverage.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/sync_app_colors_to_theme.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'aliado_catalog_layout.dart';
import 'aliado_catalog_filters_sheet.dart';
import 'aliado_promo_campaign_widgets.dart';
import 'importer_store_profile_screen.dart';
import 'package:motolink_pro_app/features/inventory/importer_inventory_dashboard.dart';
import 'package:motolink_pro_app/core/widgets/header_icon_button.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/motolink_app_bar.dart';
import 'aliado_catalog_branded_header.dart';
import 'product_detail_screen.dart';
import 'sliver_catalog_card_rows.dart';
import 'catalog_browse_layout.dart';
import '../../app/main_shell_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    this.homeRole = AppHomeRole.importador,
    this.onNotificationTap,
    this.onMessagesTap,
    this.unreadNotifications = 0,
    this.unreadMessages = 0,
    this.embedInDesktopShell = false,
    this.isActiveTab = true,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMessagesTap;
  final int unreadNotifications;
  final int unreadMessages;

  /// Sin AppBar propio cuando el shell de escritorio provee chrome.
  final bool embedInDesktopShell;
  final bool isActiveTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SyncAppColorsToTheme {
  int _catalogCrossAxisCount = 5;
  final _catalogScrollController = ScrollController();

  int get _catalogPageSize =>
      AliadoCatalogLayout.pageSizeForCount(_catalogCrossAxisCount);

  late Future<List<PartModel>> _partsFuture;
  final List<PartModel> _loadedParts = <PartModel>[];
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;
  int _productsGeneration = 0;
  int? _catalogTotal;
  CatalogFilters _activeFilters = CatalogFilters.empty;
  Set<String> _selectedImporterIds = {};
  String _selectedCategoryLabel = kAliadoCatalogAllCategoriesLabel;
  List<AliadoCatalogCategoryGroup> _categoryGroups = const [];

  late final TextEditingController _searchController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late final TextEditingController _ownerEstadoFilterController;
  late final TextEditingController _ownerCiudadFilterController;
  late final Future<List<ImporterOption>> _importersFuture;
  late final Future<List<PromoCampaignModel>> _promoFuture;
  bool _promoPopupCheckScheduled = false;
  bool _promoPopupOpen = false;
  bool _leftApp = false;
  List<PromoCampaignModel> _popupPromos = const [];

  CatalogSortMode _catalogSortMode = CatalogSortMode.defaultMode;
  double? _minOwnerRatingAvg;
  int? _minOwnerRatingCount;
  bool _onlyWithCommercialDiscount = false;
  bool _onlyEnvioIncluido = false;
  double? _allySortLat;
  double? _allySortLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _catalogScrollController.addListener(_onCatalogScroll);
    _searchController = TextEditingController();
    _minPriceController = TextEditingController();
    _maxPriceController = TextEditingController();
    _ownerEstadoFilterController = TextEditingController();
    _ownerCiudadFilterController = TextEditingController();
    if (widget.homeRole == AppHomeRole.aliado) {
      final la = widget.profile.latitude;
      final lo = widget.profile.longitude;
      if (la != null && lo != null) {
        _allySortLat = la;
        _allySortLng = lo;
      }
      _importersFuture = _publishedCatalogImporters();
      _promoFuture = SupabaseService.fetchActivePromoCampaignsForAliado();
      _searchController.addListener(_onAliadoSearchTextChanged);
      _partsFuture = _fetchProducts(reset: true);
      _refreshCatalogTotal();
      _loadCatalogCategories();
      MainShellTabController.registerAliadoCatalog(_consumeHomeRequest);
    } else if (widget.homeRole == AppHomeRole.administrador) {
      _importersFuture = Future.value(const []);
      _promoFuture = Future.value(const []);
      _partsFuture = Future.value(const []);
    } else {
      _importersFuture = Future.value(const []);
      _promoFuture = Future.value(const []);
      _partsFuture = Future.value(const []);
    }
  }

  @override
  void dispose() {
    if (widget.homeRole == AppHomeRole.aliado) {
      MainShellTabController.registerAliadoCatalog(null);
    }
    WidgetsBinding.instance.removeObserver(this);
    _catalogScrollController.removeListener(_onCatalogScroll);
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _ownerEstadoFilterController.dispose();
    _ownerCiudadFilterController.dispose();
    _catalogScrollController.dispose();
    super.dispose();
  }

  void _consumeHomeRequest() {
    final request = MainShellTabController.consumeAliadoCatalogRequest();
    if (!mounted || request == null) return;
    final f = request.filters;
    _searchController.text = f.searchQuery ?? '';
    _minPriceController.text = f.minPrice?.toString() ?? '';
    _maxPriceController.text = f.maxPrice?.toString() ?? '';
    _ownerEstadoFilterController.text = f.ownerEstado ?? '';
    _ownerCiudadFilterController.text = f.ownerCiudad ?? '';
    setState(() {
      _selectedImporterIds = f.effectiveOwnerIds.toSet();
      _selectedCategoryLabel = canonicalCatalogCategory(f.category) ??
          f.category ??
          (f.categoryAnyOf.isEmpty
              ? kAliadoCatalogAllCategoriesLabel
              : categoryFamily(
                  canonicalCatalogCategory(f.categoryAnyOf.first) ??
                      f.categoryAnyOf.first));
      _catalogSortMode = f.sortMode;
      _minOwnerRatingAvg = f.minOwnerRatingAvg;
      _minOwnerRatingCount = f.minOwnerRatingCount;
      _onlyWithCommercialDiscount =
          f.onlyWithCommercialDiscount || f.onlyUsdPromotion;
      _onlyEnvioIncluido = f.onlyEnvioIncluido;
      _activeFilters = f;
      _partsFuture = _fetchProducts(reset: true);
    });
    _refreshCatalogTotal();
    if (_catalogScrollController.hasClients) _catalogScrollController.jumpTo(0);
    if (request.campaign != null) _onPromoCampaignSelected(request.campaign!);
    if (request.openFilters) _openFiltersFromInicio();
  }

  Future<void> _openFiltersFromInicio() async {
    try {
      final importers = await _importersFuture;
      if (mounted && widget.isActiveTab) {
        await _openCatalogFiltersSheet(importers);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron abrir los filtros.')));
    }
  }

  Future<void> _refreshCatalogTotal() async {
    final filters = _activeFilters;
    try {
      final n = await SupabaseService.fetchProductsCount(filters: filters);
      if (!mounted || !identical(filters, _activeFilters)) return;
      setState(() => _catalogTotal = n);
    } catch (_) {
      if (!mounted || !identical(filters, _activeFilters)) return;
      setState(() => _catalogTotal = null);
    }
  }

  CatalogFilters _parseFiltersFromControllers() {
    final min = double.tryParse(_minPriceController.text.replaceAll(',', '.'));
    final max = double.tryParse(_maxPriceController.text.replaceAll(',', '.'));
    double? minP = min;
    double? maxP = max;
    if (minP != null && maxP != null && minP > maxP) {
      final t = minP;
      minP = maxP;
      maxP = t;
    }
    final userQ = _searchController.text.trim();
    final categoryValues = _categoryValuesFor(_selectedCategoryLabel);
    final oe = _ownerEstadoFilterController.text.trim();
    final oc = _ownerCiudadFilterController.text.trim();
    final useNearest = _catalogSortMode == CatalogSortMode.nearest;
    return CatalogFilters(
      searchQuery: userQ.isEmpty ? null : userQ,
      category: categoryValues.length == 1 ? categoryValues.first : null,
      categoryAnyOf: categoryValues.length > 1 ? categoryValues : const [],
      ownerIds: _selectedImporterIds.toList(),
      ownerEstado: oe.isEmpty ? null : oe,
      ownerCiudad: oc.isEmpty ? null : oc,
      minPrice: minP,
      maxPrice: maxP,
      onlyActiveProducts: true,
      sortMode: _catalogSortMode,
      sortReferenceLat: useNearest ? _allySortLat : null,
      sortReferenceLng: useNearest ? _allySortLng : null,
      minOwnerRatingAvg: _minOwnerRatingAvg,
      minOwnerRatingCount: _minOwnerRatingCount,
      onlyWithCommercialDiscount: _onlyWithCommercialDiscount,
      onlyUsdPromotion: _onlyWithCommercialDiscount,
      onlyEnvioIncluido: _onlyEnvioIncluido,
      brandField: _activeFilters.brandField,
    );
  }

  void _applyFiltersFromUi() {
    setState(() {
      _activeFilters = _parseFiltersFromControllers();
      _partsFuture = _fetchProducts(reset: true);
    });
    _refreshCatalogTotal();
  }

  AliadoCatalogQuickFilter get _selectedQuickFilter {
    if (_onlyEnvioIncluido) return AliadoCatalogQuickFilter.shippingIncluded;
    if (_catalogSortMode == CatalogSortMode.reputation) {
      return AliadoCatalogQuickFilter.topReputation;
    }
    if (_onlyWithCommercialDiscount) return AliadoCatalogQuickFilter.usdPromo;
    return AliadoCatalogQuickFilter.all;
  }

  void _selectQuickFilter(AliadoCatalogQuickFilter filter) {
    if (filter == _selectedQuickFilter) return;
    setState(() {
      switch (filter) {
        case AliadoCatalogQuickFilter.all:
          _onlyEnvioIncluido = false;
          _onlyWithCommercialDiscount = false;
          if (_catalogSortMode == CatalogSortMode.reputation) {
            _catalogSortMode = CatalogSortMode.defaultMode;
          }
        case AliadoCatalogQuickFilter.usdPromo:
          _onlyEnvioIncluido = false;
          _onlyWithCommercialDiscount = true;
          if (_catalogSortMode == CatalogSortMode.reputation) {
            _catalogSortMode = CatalogSortMode.defaultMode;
          }
        case AliadoCatalogQuickFilter.shippingIncluded:
          _onlyEnvioIncluido = true;
          _onlyWithCommercialDiscount = false;
          if (_catalogSortMode == CatalogSortMode.reputation) {
            _catalogSortMode = CatalogSortMode.defaultMode;
          }
        case AliadoCatalogQuickFilter.topReputation:
          _onlyEnvioIncluido = false;
          _onlyWithCommercialDiscount = false;
          _catalogSortMode = CatalogSortMode.reputation;
      }
    });
    _applyFiltersFromUi();
  }

  Future<void> _openSortSheet() async {
    final next = await showAliadoCatalogSortSheet(
      context: context,
      selected: _catalogSortMode,
    );
    if (!mounted || next == null || next == _catalogSortMode) return;
    setState(() => _catalogSortMode = next);
    if (next == CatalogSortMode.nearest) {
      final ok = await _ensureGpsForNearestSort();
      if (!mounted) return;
      if (!ok) {
        setState(() => _catalogSortMode = CatalogSortMode.defaultMode);
        return;
      }
    }
    _applyFiltersFromUi();
  }

  void _clearFilters() {
    _searchController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    _ownerEstadoFilterController.clear();
    _ownerCiudadFilterController.clear();
    setState(() {
      _selectedImporterIds = {};
      _selectedCategoryLabel = kAliadoCatalogAllCategoriesLabel;
      _catalogSortMode = CatalogSortMode.defaultMode;
      _minOwnerRatingAvg = null;
      _minOwnerRatingCount = null;
      _onlyWithCommercialDiscount = false;
      _onlyEnvioIncluido = false;
      final la = widget.profile.latitude;
      final lo = widget.profile.longitude;
      _allySortLat = la;
      _allySortLng = lo;
      _activeFilters = CatalogFilters.empty;
      _partsFuture = _fetchProducts(reset: true);
    });
    _refreshCatalogTotal();
  }

  void _applyImporterFilterFromPromo(String importadorId) {
    final id = importadorId.trim();
    if (id.isEmpty) return;
    setState(() => _selectedImporterIds = {id});
    _applyFiltersFromUi();
  }

  PartModel _withCampaignDiscount(PartModel part, PromoCampaignModel campaign) {
    final pct = campaign.effectivePercentFor(part.id);
    if (pct == null || pct <= 0) return part;
    return part.copyWith(
      activeCampaignDiscountPercent: pct,
      activePromoCampaignId: campaign.id,
    );
  }

  Future<void> _onPromoCampaignSelected(PromoCampaignModel campaign) async {
    if (!CatalogRouteLock.tryHold()) return;
    var handedOff = false;
    try {
      handedOff = await _openPromoCampaign(campaign);
    } finally {
      if (!handedOff) CatalogRouteLock.release();
    }
  }

  Future<bool> _openPromoCampaign(PromoCampaignModel campaign) async {
    if (campaign.filtersImporter) {
      final importadorId = campaign.importadorId?.trim();
      if (importadorId == null || importadorId.isEmpty) return false;
      CartService.instance.setPromoAttribution(
        importadorId: importadorId,
        campaignId: campaign.id,
      );
      _applyImporterFilterFromPromo(importadorId);
      return false;
    }
    if (campaign.opensStore) {
      final importadorId = campaign.importadorId!.trim();
      if (!mounted) return false;
      await CatalogRouteLock.pushHeld(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ImporterStoreProfileScreen(
            importerId: importadorId,
            viewer: widget.profile,
          ),
        ),
      );
      return true;
    }
    if (!campaign.opensProduct) return false;
    final importerId = campaign.importadorId!.trim();
    CartService.instance.setPromoAttribution(
      importadorId: importerId,
      campaignId: campaign.id,
    );
    final ids = campaign.resolvedProductIds;
    if (ids.isEmpty) return false;

    final byId = <String, PartModel>{};
    final missing = <String>[];
    for (final id in ids) {
      PartModel? cached;
      for (final part in _loadedParts) {
        if (part.id == id && (part.ownerId?.trim() ?? '') == importerId) {
          cached = part;
          break;
        }
      }
      if (cached != null) {
        byId[id] = _withCampaignDiscount(cached, campaign);
      } else {
        missing.add(id);
      }
    }

    if (missing.isNotEmpty && mounted) {
      final navigator = Navigator.of(context, rootNavigator: true);
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      navigator.push(route);
      try {
        final fetched = await SupabaseService.fetchVisibleImporterStoreProducts(
          importerId: importerId,
          productIds: missing,
        );
        for (final part in fetched) {
          byId[part.id] = _withCampaignDiscount(part, campaign);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudieron cargar los productos de la promoción.',
              ),
            ),
          );
        }
      } finally {
        if (route.isActive) navigator.removeRoute(route);
      }
    }

    if (!mounted) return false;
    final parts = <PartModel>[
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
    if (parts.isEmpty) return false;
    if (parts.length == 1) {
      await CatalogRouteLock.pushHeld(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(part: parts.first),
        ),
      );
      return true;
    }

    final chosen = await showAliadoPromoProductsSheet(
      context: context,
      campaign: campaign,
      parts: parts,
    );
    if (!mounted || chosen == null) return false;
    await CatalogRouteLock.pushHeld(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(part: chosen),
      ),
    );
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _leftApp = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _leftApp) {
      _leftApp = false;
      _maybeShowPromoPopup(_popupPromos);
    }
  }

  Future<void> _maybeShowPromoPopup(List<PromoCampaignModel> popups) async {
    if (!mounted || popups.isEmpty || _promoPopupOpen) return;
    _promoPopupOpen = true;
    try {
      final sorted = List<PromoCampaignModel>.from(popups)
        ..sort((a, b) => b.priority.compareTo(a.priority));
      final campaign = sorted.first;
      if (!mounted) return;
      await showAliadoPromoPopupIfDue(
        context: context,
        campaign: campaign,
        onDismissed: () {},
        onFilterImporter: campaign.filtersImporter ||
                campaign.opensStore ||
                campaign.opensProduct
            ? () => _onPromoCampaignSelected(campaign)
            : null,
      );
    } finally {
      _promoPopupOpen = false;
    }
  }

  void _onAliadoSearchTextChanged() {
    if (!mounted || widget.homeRole != AppHomeRole.aliado) return;
    setState(() {});
  }

  /// Misma UX que Inicio: lupa del header compacto abre búsqueda en sheet.
  Future<void> _openCollapsedCatalogSearch(VoidCallback? openFilters) async {
    final filterBadge = _currentFiltersDraft().activePanelFilterCount;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Buscar repuestos',
                  style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 10),
              CatalogCollapsingSearchField(
                controller: _searchController,
                autofocus: true,
                filterBadge: filterBadge,
                onSubmitted: () => Navigator.pop(sheet, 'search'),
                onOpenFilters: () => Navigator.pop(sheet, 'filters'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'filters') {
      openFilters?.call();
      return;
    }
    _applyFiltersFromUi();
  }

  AliadoCatalogFiltersDraft _currentFiltersDraft() {
    return AliadoCatalogFiltersDraft(
      categoryLabel: _selectedCategoryLabel,
      importerIds: _selectedImporterIds,
      ownerEstado: _ownerEstadoFilterController.text,
      ownerCiudad: _ownerCiudadFilterController.text,
      minPrice: _minPriceController.text,
      maxPrice: _maxPriceController.text,
      sortMode: _catalogSortMode,
      minOwnerRatingAvg: _minOwnerRatingAvg,
      minOwnerRatingCount: _minOwnerRatingCount,
      onlyWithCommercialDiscount: _onlyWithCommercialDiscount,
    );
  }

  Future<bool> _ensureGpsForNearestSort() async {
    final pos = await GeolocatorService.getCurrentLatLng();
    if (!mounted) return false;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Active el GPS y conceda permiso de ubicación para ordenar por cercanía.',
          ),
          backgroundColor: AppColors.brandBlue,
        ),
      );
      return false;
    }

    try {
      await SupabaseService.updateMyGeolocation(
        latitude: pos.lat,
        longitude: pos.lng,
      );
    } catch (_) {}

    if (!mounted) return false;
    setState(() {
      _allySortLat = pos.lat;
      _allySortLng = pos.lng;
    });
    return true;
  }

  Future<void> _applyFiltersDraft(AliadoCatalogFiltersDraft draft) async {
    setState(() {
      _selectedCategoryLabel = draft.categoryLabel;
      _selectedImporterIds = Set<String>.from(draft.importerIds);
      _ownerEstadoFilterController.text = draft.ownerEstado;
      _ownerCiudadFilterController.text = draft.ownerCiudad;
      _minPriceController.text = draft.minPrice;
      _maxPriceController.text = draft.maxPrice;
      _catalogSortMode = draft.sortMode;
      _minOwnerRatingAvg = draft.minOwnerRatingAvg;
      _minOwnerRatingCount = draft.minOwnerRatingCount;
      _onlyWithCommercialDiscount = draft.onlyWithCommercialDiscount;
    });

    if (draft.sortMode == CatalogSortMode.nearest) {
      final ok = await _ensureGpsForNearestSort();
      if (!ok && mounted) {
        setState(() => _catalogSortMode = CatalogSortMode.defaultMode);
      }
    } else {
      final la = widget.profile.latitude;
      final lo = widget.profile.longitude;
      if (la != null && lo != null) {
        setState(() {
          _allySortLat = la;
          _allySortLng = lo;
        });
      }
    }

    if (!mounted) return;
    _applyFiltersFromUi();
  }

  Future<void> _loadCatalogCategories() async {
    try {
      final rows = await SupabaseService.fetchAliadoCatalogCategories();
      if (!mounted) return;
      final groups = catalogCategoryFamilies(rows);
      setState(() {
        _categoryGroups = groups;
      });
    } catch (_) {}
  }

  List<String> _categoryValuesFor(String label) {
    if (_categoryGroups.isEmpty &&
        _activeFilters.category == label &&
        _activeFilters.categoryAnyOf.isNotEmpty) {
      return _activeFilters.categoryAnyOf;
    }
    return catalogValuesForSelection(_categoryGroups, label);
  }

  /// Proveedores con al menos un producto publicado. El resto no aparece
  /// en el filtro ni en el acceso a la vitrina del catálogo del aliado.
  Future<List<ImporterOption>> _publishedCatalogImporters() async {
    final results = await Future.wait<Object>([
      SupabaseService.fetchImporterOptions(),
      SupabaseService.fetchPublishedCatalogOwnerIds(),
    ]);
    return splitImportersByPublishedCatalog(
      importers: results[0] as List<ImporterOption>,
      publishedOwnerIds: results[1] as Set<String>,
    ).published;
  }

  Future<void> _openCatalogFiltersSheet(List<ImporterOption> importers) async {
    await _loadCatalogCategories();
    if (!mounted || !widget.isActiveTab) return;
    final result = await AliadoCatalogFiltersSheet.show(
      context,
      initial: _currentFiltersDraft(),
      importers: importers,
      categoryGroups: _categoryGroups,
      onOpenImporterStore: (id) {
        CatalogRouteLock.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ImporterStoreProfileScreen(
              importerId: id,
              viewer: widget.profile,
            ),
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    await _applyFiltersDraft(result);
  }

  Future<List<PartModel>> _fetchProducts({required bool reset}) async {
    if (reset) {
      _productsGeneration++;
      _isLoadingMore = false;
      _loadedParts.clear();
      _hasMoreProducts = true;
      if (_catalogScrollController.hasClients) {
        _catalogScrollController.jumpTo(0);
      }
    }
    if (!_hasMoreProducts) return List<PartModel>.unmodifiable(_loadedParts);

    final batch = _catalogPageSize;
    final generation = _productsGeneration;
    final nextBatch = await SupabaseService.fetchParts(
      limit: batch,
      offset: _loadedParts.length,
      filters: _activeFilters,
    );

    // Una búsqueda nueva invalida las cargas anteriores, incluida la inicial.
    if (!mounted || generation != _productsGeneration) {
      return List<PartModel>.unmodifiable(_loadedParts);
    }

    if (nextBatch.length < batch) {
      _hasMoreProducts = false;
    }
    _loadedParts.addAll(nextBatch);
    return List<PartModel>.unmodifiable(_loadedParts);
  }

  void _onCatalogScroll() {
    if (!_catalogScrollController.hasClients) return;
    if (_catalogScrollController.position.extentAfter < 640) {
      _loadMoreProducts();
    }
  }

  /// Siguiente lote al acercarse al final. Si la primera tanda no llena
  /// la pantalla, el frame siguiente vuelve a pedir.
  Future<void> _loadMoreProducts() async {
    if (!mounted || widget.homeRole != AppHomeRole.aliado) return;
    if (_isLoadingMore || !_hasMoreProducts || _loadedParts.isEmpty) return;
    setState(() => _isLoadingMore = true);
    final generation = _productsGeneration;
    try {
      await _fetchProducts(reset: false);
    } catch (_) {
      if (!mounted || generation != _productsGeneration) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar más productos.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted && generation == _productsGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  InputDecoration _searchDecoration({
    VoidCallback? onOpenFilters,
    int filterBadge = 0,
    bool showFilterButton = true,
  }) {
    Widget? suffix;
    if (onOpenFilters == null) {
      suffix = _searchController.text.trim().isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                _searchController.clear();
                _applyFiltersFromUi();
              },
            );
    } else {
      final suffixChildren = <Widget>[
        if (_searchController.text.trim().isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: () {
              _searchController.clear();
              _applyFiltersFromUi();
            },
          ),
        if (showFilterButton)
          IconButton(
            tooltip: 'Filtros',
            onPressed: onOpenFilters,
            icon: Badge(
              isLabelVisible: filterBadge > 0,
              label: Text('$filterBadge'),
              backgroundColor: AppColors.brand,
              child: Icon(
                Icons.tune,
                color:
                    filterBadge > 0 ? AppColors.brand : AppColors.textSecondary,
              ),
            ),
          ),
      ];
      if (suffixChildren.isNotEmpty) {
        suffix = Row(mainAxisSize: MainAxisSize.min, children: suffixChildren);
      }
    }

    return InputDecoration(
      hintText: 'Nombre, marca o código…',
      hintStyle: TextStyle(color: AppColors.textSecondary),
      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack reutiliza el State: hay que depender del Theme para redibujar.
    AppColors.brightness = Theme.of(context).brightness;
    final appBar = widget.embedInDesktopShell
        ? null
        : MotolinkAppBar(
            currentUserProfile: widget.profile,
            branded: widget.homeRole == AppHomeRole.aliado,
            showBcvRate: widget.homeRole != AppHomeRole.aliado,
            logoHeight: widget.homeRole == AppHomeRole.aliado
                ? MotolinkAppBarLogoSizes.aliado
                : MotolinkAppBarLogoSizes.importador,
            onNotificationTap: widget.onNotificationTap,
            unreadNotifications: widget.unreadNotifications,
            onMessagesTap: widget.onMessagesTap,
            unreadMessages: widget.unreadMessages,
            extraActions: widget.homeRole == AppHomeRole.aliado
                ? [
                    ListenableBuilder(
                      listenable: CartService.instance,
                      builder: (context, _) {
                        final n = CartService.instance.itemCount;
                        return HeaderIconButton(
                          tooltip: 'Bolsa',
                          count: n,
                          iconColor: AppColors.white,
                          icon: Icons.shopping_bag_outlined,
                          iconWidget: const LucideIcon(
                            LucideGlyph.shoppingBag,
                            size: 22,
                            color: AppColors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => CartScreen(
                                  profile: widget.profile,
                                  liveTasaBcv: BcvBasePrice.cachedRate,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ]
                : null,
          );

    if (widget.homeRole == AppHomeRole.administrador) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 64,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(height: 16),
                Text(
                  'Panel de intermediación',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Revisa y aprueba solicitudes en la pestaña «Bandeja». '
                  'Los importadores solo ven pedidos que B2B Conecta haya validado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.homeRole == AppHomeRole.importador) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        body: const ImporterInventoryDashboard(),
      );
    }

    final filterBadge = _currentFiltersDraft().activePanelFilterCount;
    final useBrandedHeader = widget.homeRole == AppHomeRole.aliado &&
        !widget.embedInDesktopShell;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: useBrandedHeader ? null : appBar,
      body: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([_importersFuture, _promoFuture]),
        builder: (context, bootstrapSnapshot) {
          final importers = bootstrapSnapshot.data != null
              ? bootstrapSnapshot.data![0] as List<ImporterOption>
              : const <ImporterOption>[];
          final promos = bootstrapSnapshot.data != null
              ? bootstrapSnapshot.data![1] as List<PromoCampaignModel>
              : const <PromoCampaignModel>[];
          final popupPromos =
              promos.where((p) => p.isPopup).toList(growable: false);

          if (bootstrapSnapshot.hasData) {
            _popupPromos = popupPromos;
          }
          if (!_promoPopupCheckScheduled && bootstrapSnapshot.hasData) {
            _promoPopupCheckScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _maybeShowPromoPopup(popupPromos);
            });
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final catalogWidth = constraints.maxWidth;
              final isDesktopCatalog =
                  AliadoCatalogLayout.isDesktop(catalogWidth);
              final crossAxisCount = AliadoCatalogLayout.crossAxisCount(
                  catalogWidth,
                  textScale: MediaQuery.textScalerOf(context).scale(14) / 14);
              final hPad = AliadoCatalogLayout.horizontalPadding(catalogWidth);
              _catalogCrossAxisCount = crossAxisCount;
              final openFilters = bootstrapSnapshot.hasError
                  ? null
                  : () => _openCatalogFiltersSheet(importers);

              final browse = CatalogBrowseLayout(
                heading: useBrandedHeader
                    ? null
                    : (widget.homeRole == AppHomeRole.aliado
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
                            child: Text(
                              'Catálogo de repuestos',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          )
                        : null),
                search: useBrandedHeader
                    ? null
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                            hPad, isDesktopCatalog ? 4 : 12, hPad, 8),
                        child: isDesktopCatalog
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: (_) => _applyFiltersFromUi(),
                                      decoration: _searchDecoration(
                                        onOpenFilters: openFilters,
                                        filterBadge: filterBadge,
                                        showFilterButton: false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: openFilters,
                                    icon: Badge(
                                      isLabelVisible: filterBadge > 0,
                                      label: Text('$filterBadge'),
                                      child: const Icon(Icons.tune, size: 20),
                                    ),
                                    label: const Text('Filtros'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.brandAccent,
                                      backgroundColor: AppColors.fieldFill,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      side: BorderSide(
                                          color: AppColors.borderSubtle),
                                    ),
                                  ),
                                ],
                              )
                            : TextField(
                                controller: _searchController,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _applyFiltersFromUi(),
                                decoration: _searchDecoration(
                                  onOpenFilters: openFilters,
                                  filterBadge: filterBadge,
                                ),
                              ),
                      ),
                quickFilters: widget.homeRole == AppHomeRole.aliado
                    ? Builder(builder: (context) {
                        final brandField = _activeFilters.brandField;
                        final brandChip = brandField == null
                            ? null
                            : InputChip(
                                label: Text(brandField.value,
                                    overflow: TextOverflow.ellipsis),
                                onDeleted: () {
                                  _activeFilters = CatalogFilters.empty;
                                  _applyFiltersFromUi();
                                },
                                deleteButtonTooltipMessage:
                                    'Quitar filtro de marca',
                              );
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                              hPad, useBrandedHeader ? 14 : 0, hPad, 8),
                          child: useBrandedHeader
                              ? AliadoCatalogToolbar(
                                  selectedFilter: _selectedQuickFilter,
                                  onFilterSelected: _selectQuickFilter,
                                  resultCount:
                                      _catalogTotal ?? _loadedParts.length,
                                  sortMode: _catalogSortMode,
                                  onSortTap: _openSortSheet,
                                  brandChip: brandChip,
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    AliadoCatalogQuickFilters(
                                      selected: _selectedQuickFilter,
                                      onSelected: _selectQuickFilter,
                                    ),
                                    if (brandChip != null) brandChip,
                                  ],
                                ),
                        );
                      })
                    : null,
                notice: _catalogSortMode == CatalogSortMode.featured &&
                        widget.homeRole == AppHomeRole.aliado
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF6E5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE8A317).withOpacity(0.35),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: Color(0xFFE8A317),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Orden Destacados: primero los proveedores con '
                                  'sello dorado por alto volumen.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.35,
                                    color: Color(0xFF8A5A00),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : null,
                content: FutureBuilder<List<PartModel>>(
                  future: _partsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _loadedParts.isEmpty) {
                      return CatalogGridSkeleton(
                        maxWidth: catalogWidth,
                        horizontalPadding: hPad,
                      );
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 120),
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red.shade700),
                          const SizedBox(height: 12),
                          Text(
                            'No se pudieron cargar los repuestos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    }
                    final parts = _loadedParts;
                    final resultsLabel =
                        '${_catalogTotal ?? parts.length} repuestos encontrados';
                    final resultsStyle = TextStyle(
                      fontSize: isDesktopCatalog ? 14 : 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    );
                    final showInlineResultsMeta = !useBrandedHeader;

                    if (parts.isEmpty) {
                      return ListView(
                        children: [
                          if (showInlineResultsMeta)
                            Padding(
                              padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 8),
                              child: Text(resultsLabel, style: resultsStyle),
                            ),
                          const SizedBox(height: 120),
                          Center(
                            child: Text(
                              _activeFilters.hasAnyFilter
                                  ? 'No encontramos repuestos con esa búsqueda.'
                                  : 'No hay repuestos disponibles.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                              child: TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Ver todos los repuestos'),
                          )),
                        ],
                      );
                    }

                    // Las vallas publicitarias viven solo en Inicio.
                    if (_hasMoreProducts && !_isLoadingMore) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _onCatalogScroll();
                      });
                    }
                    return CustomScrollView(
                      controller: _catalogScrollController,
                      slivers: [
                        if (showInlineResultsMeta)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                hPad,
                                4,
                                hPad,
                                0,
                              ),
                              child: Text(
                                resultsLabel,
                                style: resultsStyle,
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            hPad,
                            0,
                            hPad,
                            16,
                          ),
                          sliver: SliverLayoutBuilder(
                            builder: (context, sliverConstraints) {
                              final spacing = AliadoCatalogLayout.gridSpacing(
                                catalogWidth,
                              );
                              final showDistance =
                                  _activeFilters.sortByDistanceFromReference;
                              return SliverCatalogCardRows(
                                columns: crossAxisCount,
                                spacing: spacing,
                                itemCount: parts.length,
                                itemBuilder: (context, index) {
                                  final p = parts[index];
                                  return AliadoProductCard(
                                    part: p,
                                    profile: widget.profile,
                                    compact: true,
                                    showDistanceChips: showDistance,
                                    onTap: () {
                                      CatalogRouteLock.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (ctx) => ProductDetailScreen(
                                            part: p,
                                          ),
                                        ),
                                      );
                                    },
                                    onImporterTap:
                                        (p.ownerId?.trim().isNotEmpty ?? false)
                                            ? () {
                                                CatalogRouteLock.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        ImporterStoreProfileScreen(
                                                      importerId:
                                                          p.ownerId!.trim(),
                                                      viewer: widget.profile,
                                                    ),
                                                  ),
                                                );
                                              }
                                            : null,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        if (_isLoadingMore)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                footer: CatalogCartBar(
                    onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  CartScreen(profile: widget.profile)),
                        )),
              );

              if (!useBrandedHeader) return browse;

              final brandField = _activeFilters.brandField;
              final brandChip = brandField == null
                  ? null
                  : InputChip(
                      label: Text(brandField.value,
                          overflow: TextOverflow.ellipsis),
                      onDeleted: () {
                        _activeFilters = CatalogFilters.empty;
                        _applyFiltersFromUi();
                      },
                      deleteButtonTooltipMessage: 'Quitar filtro de marca',
                    );
              final featuredNotice =
                  _catalogSortMode == CatalogSortMode.featured
                      ? Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6E5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    const Color(0xFFE8A317).withOpacity(0.35),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: Color(0xFFE8A317),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Orden Destacados: primero los proveedores con '
                                    'sello dorado por alto volumen.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.35,
                                      color: Color(0xFF8A5A00),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null;

              return Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<List<PartModel>>(
                    future: _partsFuture,
                    builder: (context, snapshot) {
                      return CustomScrollView(
                        controller: _catalogScrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          AliadoCatalogBrandedHeader(
                            profile: widget.profile,
                            searchController: _searchController,
                            onSearchSubmitted: _applyFiltersFromUi,
                            onOpenSearch: () =>
                                _openCollapsedCatalogSearch(openFilters),
                            onOpenFilters: openFilters,
                            onMessagesTap: widget.onMessagesTap,
                            onNotificationTap: widget.onNotificationTap,
                            unreadMessages: widget.unreadMessages,
                            unreadNotifications: widget.unreadNotifications,
                            filterBadge: filterBadge,
                          ),
                          AliadoCatalogPinnedFiltersHeader(
                            horizontalPadding: hPad,
                            hasBrandChip: brandChip != null,
                            child: AliadoCatalogToolbar(
                              selectedFilter: _selectedQuickFilter,
                              onFilterSelected: _selectQuickFilter,
                              resultCount:
                                  _catalogTotal ?? _loadedParts.length,
                              sortMode: _catalogSortMode,
                              onSortTap: _openSortSheet,
                              brandChip: brandChip,
                            ),
                          ),
                          if (featuredNotice != null)
                            SliverToBoxAdapter(child: featuredNotice),
                          ..._brandedCatalogContentSlivers(
                            snapshot: snapshot,
                            catalogWidth: catalogWidth,
                            hPad: hPad,
                            crossAxisCount: crossAxisCount,
                          ),
                        ],
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: CatalogCartBar(
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CartScreen(profile: widget.profile),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _brandedCatalogContentSlivers({
    required AsyncSnapshot<List<PartModel>> snapshot,
    required double catalogWidth,
    required double hPad,
    required int crossAxisCount,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        _loadedParts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: true,
          child: CatalogGridSkeleton(
            maxWidth: catalogWidth,
            horizontalPadding: hPad,
          ),
        ),
      ];
    }
    if (snapshot.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: Colors.red.shade700),
                const SizedBox(height: 12),
                Text(
                  'No se pudieron cargar los repuestos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final parts = _loadedParts;
    if (parts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _activeFilters.hasAnyFilter
                    ? 'No encontramos repuestos con esa búsqueda.'
                    : 'No hay repuestos disponibles.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Ver todos los repuestos'),
              ),
            ],
          ),
        ),
      ];
    }

    if (_hasMoreProducts && !_isLoadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onCatalogScroll();
      });
    }

    final showDistance = _activeFilters.sortByDistanceFromReference;
    final spacing = AliadoCatalogLayout.gridSpacing(catalogWidth);
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
        sliver: SliverCatalogCardRows(
          columns: crossAxisCount,
          spacing: spacing,
          itemCount: parts.length,
          itemBuilder: (context, index) {
            final p = parts[index];
            return AliadoProductCard(
              part: p,
              profile: widget.profile,
              compact: true,
              showDistanceChips: showDistance,
              onTap: () {
                CatalogRouteLock.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (ctx) => ProductDetailScreen(part: p),
                  ),
                );
              },
              onImporterTap: (p.ownerId?.trim().isNotEmpty ?? false)
                  ? () {
                      CatalogRouteLock.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ImporterStoreProfileScreen(
                            importerId: p.ownerId!.trim(),
                            viewer: widget.profile,
                          ),
                        ),
                      );
                    }
                  : null,
            );
          },
        ),
      ),
      if (_isLoadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 72)),
    ];
  }
}
