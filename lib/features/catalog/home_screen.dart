import 'package:flutter/material.dart';

import 'aliado_catalog_categories.dart';
import 'aliado_catalog_filters_draft.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'catalog_filters.dart';
import 'catalog_route_lock.dart';
import 'catalog_sort_mode.dart';
import 'promo_campaign_model.dart';
import 'part_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/geolocator_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/admin/admin_catalog_coverage.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'aliado_catalog_layout.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'aliado_catalog_filters_sheet.dart';
import 'aliado_promo_campaign_widgets.dart';
import 'catalog_product_price_display.dart';
import 'product_catalog_pricing.dart';
import 'product_warranty_seal.dart';
import 'importer_catalog_logo.dart';
import 'importer_catalog_seals.dart';
import 'importer_store_profile_screen.dart';
import 'package:motolink_pro_app/features/inventory/importer_inventory_dashboard.dart';
import 'package:motolink_pro_app/core/widgets/header_icon_button.dart';
import 'package:motolink_pro_app/core/widgets/motolink_app_bar.dart';
import 'favorite_heart_button.dart';
import 'product_detail_screen.dart';

String _aliadoGreeting(String? businessName) {
  final name = businessName?.trim();
  if (name == null || name.isEmpty) return 'Hola';
  return 'Hola, $name';
}

String _distanceChipLabel(PartModel part) {
  final km = part.distanceKmFromReference;
  if (km == null) return 'Distancia no disponible';
  if (km < 1) {
    final m = (km * 1000).round();
    return 'A $m m';
  }
  return 'A ${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

String _ownerLocationLine(PartModel part) {
  final e = part.ownerEstado?.trim();
  final c = part.ownerCiudad?.trim();
  if ((e == null || e.isEmpty) && (c == null || c.isEmpty)) return '';
  if (e != null && e.isNotEmpty && c != null && c.isNotEmpty) {
    return '$e · $c';
  }
  return e ?? c ?? '';
}

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
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMessagesTap;
  final int unreadNotifications;
  final int unreadMessages;

  /// Sin AppBar propio cuando el shell de escritorio provee chrome.
  final bool embedInDesktopShell;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _catalogCrossAxisCount = 5;
  final _catalogScrollController = ScrollController();

  int get _catalogPageSize =>
      AliadoCatalogLayout.pageSizeForCount(_catalogCrossAxisCount);

  late Future<List<PartModel>> _partsFuture;
  final List<PartModel> _loadedParts = <PartModel>[];
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;
  int? _catalogTotal;
  int _catalogViewPage = 0;
  static const _catalogVisibleSize = 10;
  CatalogFilters _activeFilters = CatalogFilters.empty;
  Set<String> _selectedImporterIds = {};
  String _selectedCategoryLabel = kAliadoCatalogAllCategoriesLabel;
  List<String> _catalogCategories = const [];
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
  double? _allySortLat;
  double? _allySortLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _ownerEstadoFilterController.dispose();
    _ownerCiudadFilterController.dispose();
    _catalogScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshCatalogTotal() async {
    try {
      final n =
          await SupabaseService.fetchProductsCount(filters: _activeFilters);
      if (!mounted) return;
      setState(() => _catalogTotal = n);
    } catch (_) {
      if (!mounted) return;
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
    );
  }

  void _applyFiltersFromUi() {
    setState(() {
      _activeFilters = _parseFiltersFromControllers();
      _partsFuture = _fetchProducts(reset: true);
    });
    _refreshCatalogTotal();
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
    if (!campaign.hasProductDiscount) return part;
    return part.copyWith(
      activeCampaignDiscountPercent: campaign.discountPercent,
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

  Future<void> _openActivePromotionsSheet(
    List<PromoCampaignModel> campaigns,
  ) async {
    await showAliadoActivePromotionsSheet(
      context: context,
      campaigns: campaigns,
      onPromoCampaignSelected: _onPromoCampaignSelected,
    );
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
        onFilterImporter:
            campaign.filtersImporter || campaign.opensStore || campaign.opensProduct
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

  void _setCatalogSortMode(CatalogSortMode mode) {
    setState(() => _catalogSortMode = mode);
  }

  Future<bool> _ensureGpsForNearestSort() async {
    final pos = await GeolocatorService.getCurrentLatLng();
    if (!mounted) return false;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
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
      final groups = groupAliadoCatalogCategories(rows);
      setState(() {
        _categoryGroups = groups;
        _catalogCategories = [for (final group in groups) group.label];
      });
    } catch (_) {}
  }

  List<String> _categoryValuesFor(String label) {
    final wanted = label.trim();
    if (wanted.isEmpty || wanted == kAliadoCatalogAllCategoriesLabel) {
      return const [];
    }
    for (final group in _categoryGroups) {
      if (group.label == wanted || group.values.contains(wanted)) {
        return group.values;
      }
    }
    return [wanted];
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
    if (!mounted) return;
    final result = await AliadoCatalogFiltersSheet.show(
      context,
      initial: _currentFiltersDraft(),
      importers: importers,
      categories: _catalogCategories,
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
      _loadedParts.clear();
      _hasMoreProducts = true;
      _catalogViewPage = 0;
      if (_catalogScrollController.hasClients) {
        _catalogScrollController.jumpTo(0);
      }
    }
    if (!_hasMoreProducts) return List<PartModel>.unmodifiable(_loadedParts);

    final batch = _catalogPageSize < _catalogVisibleSize
        ? _catalogVisibleSize
        : _catalogPageSize;
    final nextBatch = await SupabaseService.fetchParts(
      limit: batch,
      offset: _loadedParts.length,
      filters: _activeFilters,
    );

    if (nextBatch.length < batch) {
      _hasMoreProducts = false;
    }
    _loadedParts.addAll(nextBatch);
    return List<PartModel>.unmodifiable(_loadedParts);
  }

  Future<void> _openCatalogViewPage(int index) async {
    final need = (index + 1) * _catalogVisibleSize;
    while (mounted && _loadedParts.length < need && _hasMoreProducts) {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
      try {
        await _fetchProducts(reset: false);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron cargar más productos.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      } finally {
        if (mounted) setState(() => _isLoadingMore = false);
      }
    }
    if (!mounted) return;
    setState(() => _catalogViewPage = index);
    if (_catalogScrollController.hasClients) {
      _catalogScrollController.jumpTo(0);
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
                color: filterBadge > 0
                    ? AppColors.brand
                    : AppColors.textSecondary,
              ),
            ),
          ),
      ];
      if (suffixChildren.isNotEmpty) {
        suffix = Row(mainAxisSize: MainAxisSize.min, children: suffixChildren);
      }
    }

    return InputDecoration(
      hintText: 'Buscar repuesto…',
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

  Widget _activeFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return InputChip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      backgroundColor: AppColors.brand.withOpacity(0.12),
      side: BorderSide(color: AppColors.brand.withOpacity(0.35)),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget? _buildActiveFilterChipsRow() {
    final draft = _currentFiltersDraft();
    final chips = <Widget>[];

    if (draft.hasCategoryFilter) {
      chips.add(_activeFilterChip(
        label: draft.categoryLabel,
        onDeleted: () {
          setState(() => _selectedCategoryLabel = kAliadoCatalogAllCategoriesLabel);
          _applyFiltersFromUi();
        },
      ));
    }
    if (draft.hasImporterFilter) {
      final n = draft.importerIds.length;
      chips.add(_activeFilterChip(
        label: n == 1 ? '1 proveedor' : '$n proveedores',
        onDeleted: () {
          setState(() => _selectedImporterIds = {});
          _applyFiltersFromUi();
        },
      ));
    }
    final est = draft.ownerEstado.trim();
    if (est.isNotEmpty) {
      chips.add(_activeFilterChip(
        label: 'Estado: $est',
        onDeleted: () {
          _ownerEstadoFilterController.clear();
          _applyFiltersFromUi();
        },
      ));
    }
    final ciu = draft.ownerCiudad.trim();
    if (ciu.isNotEmpty) {
      chips.add(_activeFilterChip(
        label: 'Ciudad: $ciu',
        onDeleted: () {
          _ownerCiudadFilterController.clear();
          _applyFiltersFromUi();
        },
      ));
    }
    final min = draft.minPrice.trim();
    final max = draft.maxPrice.trim();
    if (min.isNotEmpty || max.isNotEmpty) {
      final priceLabel = min.isNotEmpty && max.isNotEmpty
          ? 'REF $min – $max'
          : min.isNotEmpty
              ? 'REF desde $min'
              : 'REF hasta $max';
      chips.add(_activeFilterChip(
        label: priceLabel,
        onDeleted: () {
          _minPriceController.clear();
          _maxPriceController.clear();
          _applyFiltersFromUi();
        },
      ));
    }
    if (draft.hasNonDefaultSort) {
      chips.add(_activeFilterChip(
        label: 'Orden: ${draft.sortMode.labelEs}',
        onDeleted: () {
          _setCatalogSortMode(CatalogSortMode.defaultMode);
          _applyFiltersFromUi();
        },
      ));
    }
    if (draft.minOwnerRatingAvg != null && draft.minOwnerRatingAvg! > 0) {
      chips.add(_activeFilterChip(
        label: '≥ ${draft.minOwnerRatingAvg!.toStringAsFixed(1)} ★',
        onDeleted: () {
          setState(() => _minOwnerRatingAvg = null);
          _applyFiltersFromUi();
        },
      ));
    }
    if (draft.minOwnerRatingCount != null && draft.minOwnerRatingCount! > 0) {
      chips.add(_activeFilterChip(
        label: '≥ ${draft.minOwnerRatingCount} valoraciones',
        onDeleted: () {
          setState(() => _minOwnerRatingCount = null);
          _applyFiltersFromUi();
        },
      ));
    }
    if (draft.hasCommercialDiscountFilter) {
      chips.add(_activeFilterChip(
        label: 'Con descuentos',
        onDeleted: () {
          setState(() => _onlyWithCommercialDiscount = false);
          _applyFiltersFromUi();
        },
      ));
    }

    if (chips.isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton(
            onPressed: _clearFilters,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Limpiar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = widget.embedInDesktopShell
        ? null
        : MotolinkAppBar(
      currentUserProfile: widget.profile,
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
                    tooltip: 'Carrito',
                    count: n,
                    icon: n > 0
                        ? Icons.shopping_cart
                        : Icons.shopping_cart_outlined,
                    onPressed: () {
                      Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => CartScreen(
                            profile: widget.profile,
                            liveTasaBcv: null,
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
    final activeFilterChips = _buildActiveFilterChipsRow();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([_importersFuture, _promoFuture]),
        builder: (context, bootstrapSnapshot) {
          final importers = bootstrapSnapshot.data != null
              ? bootstrapSnapshot.data![0] as List<ImporterOption>
              : const <ImporterOption>[];
          final promos = bootstrapSnapshot.data != null
              ? bootstrapSnapshot.data![1] as List<PromoCampaignModel>
              : const <PromoCampaignModel>[];
          final bannerPromos =
              promos.where((p) => p.isBanner).toList(growable: false);
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
              final crossAxisCount =
                  AliadoCatalogLayout.crossAxisCount(catalogWidth);
              final hPad =
                  AliadoCatalogLayout.horizontalPadding(catalogWidth);
              _catalogCrossAxisCount = crossAxisCount;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.homeRole == AppHomeRole.aliado)
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
                      child: Text(
                        _aliadoGreeting(widget.profile.businessName),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, isDesktopCatalog ? 4 : 12, hPad, 8),
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
                                    onOpenFilters: bootstrapSnapshot.hasError
                                        ? null
                                        : () => _openCatalogFiltersSheet(importers),
                                    filterBadge: filterBadge,
                                    showFilterButton: false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: bootstrapSnapshot.hasError
                                    ? null
                                    : () => _openCatalogFiltersSheet(importers),
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
                                  side: BorderSide(color: AppColors.borderSubtle),
                                ),
                              ),
                            ],
                          )
                        : TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _applyFiltersFromUi(),
                            decoration: _searchDecoration(
                              onOpenFilters: bootstrapSnapshot.hasError
                                  ? null
                                  : () => _openCatalogFiltersSheet(importers),
                              filterBadge: filterBadge,
                            ),
                          ),
                  ),
                  if (activeFilterChips != null) activeFilterChips,
                  if (_catalogSortMode == CatalogSortMode.featured &&
                      widget.homeRole == AppHomeRole.aliado)
                    Padding(
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
                    ),
                  if (promos.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _openActivePromotionsSheet(promos),
                          icon: const Icon(Icons.campaign_outlined, size: 18),
                          label: Text('Promociones (${promos.length})'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brand,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: FutureBuilder<List<PartModel>>(
                      future: _partsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            _loadedParts.isEmpty) {
                          return const _LoadingState();
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

                        if (parts.isEmpty) {
                          return ListView(
                            children: [
                              if (bannerPromos.isNotEmpty)
                                AliadoPromoBannerCarousel(
                                  campaigns: bannerPromos,
                                  onPromoCampaignSelected:
                                      _onPromoCampaignSelected,
                                  compact: isDesktopCatalog,
                                ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 8),
                                child: Text(resultsLabel, style: resultsStyle),
                              ),
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  _activeFilters.hasAnyFilter
                                      ? 'No hay resultados con esos filtros.'
                                      : 'No hay repuestos disponibles.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          );
                        }

                        // Un solo scroll: la valla va arriba del contenido y
                        // se desplaza con el catálogo (deja de quedar fija).
                        final visibleParts = sliceListPage(
                          items: parts,
                          pageIndex: _catalogViewPage,
                          pageSize: _catalogVisibleSize,
                        );
                        return Stack(
                          children: [
                            CustomScrollView(
                                controller: _catalogScrollController,
                                slivers: [
                                  if (bannerPromos.isNotEmpty)
                                    SliverToBoxAdapter(
                                      child: AliadoPromoBannerCarousel(
                                        campaigns: bannerPromos,
                                        onPromoCampaignSelected:
                                            _onPromoCampaignSelected,
                                        compact: isDesktopCatalog,
                                      ),
                                    ),
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
                                      _isLoadingMore ? 56 : 16,
                                    ),
                                    sliver: SliverLayoutBuilder(
                                      builder: (context, sliverConstraints) {
                                        final spacing =
                                            AliadoCatalogLayout.gridSpacing(
                                          catalogWidth,
                                        );
                                        final extent =
                                            sliverConstraints.crossAxisExtent;
                                        final tile = (extent -
                                                spacing * (crossAxisCount - 1)) /
                                            crossAxisCount;
                                        final showDistance = _activeFilters
                                            .sortByDistanceFromReference;
                                        return SliverGrid(
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount,
                                            mainAxisSpacing: spacing,
                                            crossAxisSpacing: spacing,
                                            childAspectRatio: AliadoCatalogLayout
                                                .childAspectRatio(
                                              tileWidth: tile,
                                              showDistance: showDistance,
                                            ),
                                          ),
                                          delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                              final p = visibleParts[index];
                                              return _ProductGridCard(
                                            part: p,
                                            profile: widget.profile,
                                            compact: true,
                                            showDistanceChips: showDistance,
                                            onTap: () {
                                              CatalogRouteLock.push(
                                                context,
                                                MaterialPageRoute<void>(
                                                  builder: (ctx) =>
                                                      ProductDetailScreen(
                                                    part: p,
                                                  ),
                                                ),
                                              );
                                            },
                                            onImporterTap: (p.ownerId
                                                        ?.trim()
                                                        .isNotEmpty ??
                                                    false)
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
                                            childCount: visibleParts.length,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        hPad,
                                        4,
                                        hPad,
                                        16,
                                      ),
                                      child: ListPageBar(
                                        total: _catalogTotal ?? parts.length,
                                        hasMore: _catalogTotal == null &&
                                            _hasMoreProducts,
                                        pageIndex: _catalogViewPage,
                                        pageSize: _catalogVisibleSize,
                                        pageSizeOptions: const [
                                          _catalogVisibleSize,
                                        ],
                                        onPageIndex: (index) {
                                          _openCatalogViewPage(index);
                                        },
                                        onPageSize: (_) {},
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (_isLoadingMore)
                              const Positioned(
                                left: 0,
                                right: 0,
                                bottom: 12,
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
                          ],
                        );
                      },
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
}

class _ProductGridCard extends StatelessWidget {
  const _ProductGridCard({
    required this.part,
    required this.profile,
    this.compact = false,
    this.showDistanceChips = false,
    this.onTap,
    this.onImporterTap,
  });

  final PartModel part;
  final ProfileModel profile;
  final bool compact;
  final bool showDistanceChips;
  final VoidCallback? onTap;
  final VoidCallback? onImporterTap;

  @override
  Widget build(BuildContext context) {
    final importer = (part.ownerBusinessName ?? '').trim();
    final importerLine = importer.isNotEmpty ? importer : 'Sin proveedor';
    final category = (part.category ?? '').trim();
    final locLine = _ownerLocationLine(part);
    final hasRating =
        part.ownerRatingAvg != null && (part.ownerRatingCount ?? 0) > 0;
    final stockDetail = part.hasOwnerMinOrderAmount
        ? '${part.minOrderQtyLabelEs} · ${part.ownerMinOrderAmountLabelEs}'
        : part.minOrderQtyLabelEs;
    final refUnit = ProductCatalogPricing.aliadoUnitUsd(
      listPriceUsd: part.precio,
      salePriceUsd: part.salePriceUsd,
      discountRules: part.discountRules,
      campaignDiscountPercent: part.activeCampaignDiscountPercent,
    );

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: AppDecorations.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AliadoCatalogLayout.cardPadH,
              AliadoCatalogLayout.cardPadTop,
              AliadoCatalogLayout.cardPadH,
              AliadoCatalogLayout.cardPadBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: AliadoCatalogLayout.cardImageAspect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: ProductDetailScreen.heroImageTag(part),
                          child: part.coverImageUrl != null &&
                                  part.coverImageUrl!.isNotEmpty
                              ? Image.network(
                                  part.coverImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholder(compact),
                                )
                              : _placeholder(compact),
                        ),
                        if (part.isCatalogVerified || part.isCatalogFeatured)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: ImporterCatalogSealsRow(
                              verified: part.isCatalogVerified,
                              featured: part.isCatalogFeatured,
                              compact: true,
                              spacing: 4,
                            ),
                          ),
                        if (part.hasWarranty)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: ProductWarrantySeal(compact: true),
                          ),
                        if (profile.isAliado)
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
                const SizedBox(height: AliadoCatalogLayout.cardGapImage),
                SizedBox(
                  height: AliadoCatalogLayout.cardTitleHeight,
                  child: Text(
                    part.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: AliadoCatalogLayout.cardGapTight),
                SizedBox(
                  height: AliadoCatalogLayout.cardCategoryHeight,
                  child: category.isEmpty
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatCatalogCategoryLabel(category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                              height: 1.1,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: AliadoCatalogLayout.cardGapTight),
                SizedBox(
                  height: AliadoCatalogLayout.cardSupplierHeight,
                  child: InkWell(
                  onTap: onImporterTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      ImporterCatalogLogo(
                        storagePath: part.ownerLogoStoragePath,
                        size: 16,
                      ),
                      if (part.ownerLogoStoragePath?.trim().isNotEmpty == true)
                        const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          importerLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: onImporterTap != null
                                ? AppColors.brand
                                : AppColors.textSecondary,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (hasRating) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Colors.amber.shade800,
                        ),
                        Text(
                          part.ownerRatingAvg!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ),
                if (!compact && locLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    locLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.1,
                    ),
                  ),
                ],
                if (showDistanceChips) ...[
                  const SizedBox(height: AliadoCatalogLayout.cardGapTight),
                  SizedBox(
                    height: AliadoCatalogLayout.cardDistanceHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _distanceChipLabel(part),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AliadoCatalogLayout.cardGapSection),
                SizedBox(
                  height: AliadoCatalogLayout.cardPriceHeight,
                  child: CatalogProductPriceDisplay(
                    listPriceUsd: part.precio,
                    salePriceUsd: part.salePriceUsd,
                    discountRules: part.discountRules,
                    campaignDiscountPercent: part.activeCampaignDiscountPercent,
                    catalogGrid: true,
                    compact: true,
                    showPromotionChips: false,
                    ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                  ),
                ),
                SizedBox(
                  height: AliadoCatalogLayout.cardOfferHeight,
                  child: CatalogProductOfferChips(
                    listPriceUsd: part.precio,
                    salePriceUsd: part.salePriceUsd,
                    discountRules: part.discountRules,
                    campaignDiscountPercent:
                        part.activeCampaignDiscountPercent,
                    refUnitUsd: refUnit,
                    compact: true,
                    ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                  ),
                ),
                const SizedBox(height: AliadoCatalogLayout.cardGapSection),
                SizedBox(
                  height: AliadoCatalogLayout.cardStockHeight,
                  child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${part.stock} en stock',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.successGreen,
                        ),
                      ),
                      TextSpan(
                        text: ' · $stockDetail',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(bool compact) {
    return ColoredBox(
      color: AppColors.surfaceTinted,
      child: Icon(
        Icons.image_outlined,
        size: compact ? 28 : 34,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppDecorations.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: AppColors.brand,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Cargando repuestos...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
