import 'package:flutter/material.dart';

import 'aliado_catalog_filters_draft.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'catalog_filters.dart';
import 'catalog_sort_mode.dart';
import 'promo_campaign_model.dart';
import 'part_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/geolocator_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'aliado_catalog_layout.dart';
import 'promo_popup_frequency.dart';
import 'aliado_catalog_filters_sheet.dart';
import 'aliado_promo_campaign_widgets.dart';
import 'catalog_product_price_display.dart';
import 'product_warranty_seal.dart';
import 'importer_catalog_logo.dart';
import 'package:motolink_pro_app/features/inventory/importer_inventory_dashboard.dart';
import 'package:motolink_pro_app/core/widgets/motolink_app_bar.dart';
import 'product_detail_screen.dart';

const _kCategorySearchTokens = <String, String?>{
  'Todos': null,
  'Frenos': 'freno',
  'Transmisión': 'transmis',
  'Motor': 'motor',
  'Eléctrico': 'eléctric',
};

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
    this.unreadNotifications = 0,
    this.embedInDesktopShell = false,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final VoidCallback? onNotificationTap;
  final int unreadNotifications;

  /// Sin AppBar propio cuando el shell de escritorio provee chrome.
  final bool embedInDesktopShell;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _catalogCrossAxisCount = 2;

  int get _catalogPageSize => _catalogCrossAxisCount * 4;

  late Future<List<PartModel>> _partsFuture;
  final List<PartModel> _loadedParts = <PartModel>[];
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;
  int? _catalogTotal;
  CatalogFilters _activeFilters = CatalogFilters.empty;
  Set<String> _selectedImporterIds = {};
  String _selectedCategoryLabel = 'Todos';

  late final TextEditingController _searchController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late final TextEditingController _ownerEstadoFilterController;
  late final TextEditingController _ownerCiudadFilterController;
  late final Future<List<ImporterOption>> _importersFuture;
  late final Future<List<PromoCampaignModel>> _promoFuture;
  bool _promoPopupCheckScheduled = false;


  CatalogSortMode _catalogSortMode = CatalogSortMode.recommended;
  double? _minOwnerRatingAvg;
  int? _minOwnerRatingCount;
  bool _onlyWithCommercialDiscount = false;
  double? _allySortLat;
  double? _allySortLng;

  @override
  void initState() {
    super.initState();
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
      _importersFuture = SupabaseService.fetchImporterOptions();
      _promoFuture = SupabaseService.fetchActivePromoCampaignsForAliado();
      _searchController.addListener(_onAliadoSearchTextChanged);
      _partsFuture = _fetchProducts(reset: true);
      _refreshCatalogTotal();
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
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _ownerEstadoFilterController.dispose();
    _ownerCiudadFilterController.dispose();
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
    final catToken = _kCategorySearchTokens[_selectedCategoryLabel];
    final combined = [userQ, if (catToken != null && catToken.isNotEmpty) catToken]
        .where((e) => e.isNotEmpty)
        .join(' ');
    final oe = _ownerEstadoFilterController.text.trim();
    final oc = _ownerCiudadFilterController.text.trim();
    final useNearest = _catalogSortMode == CatalogSortMode.nearest;
    return CatalogFilters(
      searchQuery: combined.isEmpty ? null : combined,
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
      _selectedCategoryLabel = 'Todos';
      _catalogSortMode = CatalogSortMode.recommended;
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

  void _onPromoCampaignSelected(PromoCampaignModel campaign) {
    if (!campaign.filtersImporter) return;
    final importadorId = campaign.importadorId?.trim();
    if (importadorId == null || importadorId.isEmpty) return;
    CartService.instance.setPromoAttribution(
      importadorId: importadorId,
      campaignId: campaign.id,
    );
    _applyImporterFilterFromPromo(importadorId);
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

  Future<void> _maybeShowPromoPopup(List<PromoCampaignModel> popups) async {
    if (!mounted || popups.isEmpty) return;
    final sorted = List<PromoCampaignModel>.from(popups)
      ..sort((a, b) => b.priority.compareTo(a.priority));
    for (final c in sorted) {
      if (!await PromoPopupFrequency.shouldShow(c.id)) continue;
      if (!mounted) return;
      await showAliadoPromoPopupIfDue(
        context: context,
        campaign: c,
        onDismissed: () => PromoPopupFrequency.markShown(c.id),
        onFilterImporter: c.filtersImporter
            ? () => _onPromoCampaignSelected(c)
            : null,
      );
      return;
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
        setState(() => _catalogSortMode = CatalogSortMode.recommended);
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

  Future<void> _openCatalogFiltersSheet(List<ImporterOption> importers) async {
    final result = await AliadoCatalogFiltersSheet.show(
      context,
      initial: _currentFiltersDraft(),
      importers: importers,
    );
    if (result == null || !mounted) return;
    await _applyFiltersDraft(result);
  }

  Future<List<PartModel>> _fetchProducts({required bool reset}) async {
    if (reset) {
      _loadedParts.clear();
      _hasMoreProducts = true;
    }
    if (!_hasMoreProducts) return List<PartModel>.unmodifiable(_loadedParts);

    final nextBatch = await SupabaseService.fetchParts(
      limit: _catalogPageSize,
      offset: _loadedParts.length,
      filters: _activeFilters,
    );

    if (nextBatch.length < _catalogPageSize) {
      _hasMoreProducts = false;
    }
    _loadedParts.addAll(nextBatch);
    return List<PartModel>.unmodifiable(_loadedParts);
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreProducts) return;
    _isLoadingMore = true;
    final freshFuture = _fetchProducts(reset: false);
    setState(() {
      _partsFuture = freshFuture;
    });
    try {
      await freshFuture;
      if (!mounted) return;
      if (!_hasMoreProducts) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya no hay mas productos para cargar.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isLoadingMore = false;
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
          setState(() => _selectedCategoryLabel = 'Todos');
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
          _setCatalogSortMode(CatalogSortMode.recommended);
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
      extraActions: widget.homeRole == AppHomeRole.aliado
          ? [
              ListenableBuilder(
                listenable: CartService.instance,
                builder: (context, _) {
                  final n = CartService.instance.itemCount;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined),
                        color: AppColors.textSecondary,
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
                      ),
                      if (n > 0)
                        Positioned(
                          right: 4,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              n > 99 ? '99+' : '$n',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
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
              final gridSpacing =
                  AliadoCatalogLayout.gridSpacing(catalogWidth);
              _catalogCrossAxisCount = crossAxisCount;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  if (_catalogSortMode == CatalogSortMode.reputation &&
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
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.leaderboard_outlined,
                              size: 18,
                              color: Colors.amber.shade900,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ranking por reputación (últ. 100 valoraciones). '
                                'Los proveedores mejor calificados aparecen primero.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: Colors.amber.shade900,
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
                  AliadoPromoBannerCarousel(
                    campaigns: bannerPromos,
                    onPromoCampaignSelected: _onPromoCampaignSelected,
                    compact: isDesktopCatalog,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 8),
                    child: Text(
                      '${_catalogTotal ?? _loadedParts.length} repuestos encontrados',
                      style: TextStyle(
                        fontSize: isDesktopCatalog ? 14 : 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
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
                        final parts = snapshot.data ?? [];
                        if (parts.isEmpty) {
                          return ListView(
                            children: [
                              const SizedBox(height: 160),
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
                        return Column(
                          children: [
                            Expanded(
                              child: GridView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  hPad,
                                  0,
                                  hPad,
                                  8,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: gridSpacing,
                                  crossAxisSpacing: gridSpacing,
                                  childAspectRatio:
                                      AliadoCatalogLayout.childAspectRatio(
                                    catalogWidth,
                                    showDistance: _activeFilters
                                        .sortByDistanceFromReference,
                                  ),
                                ),
                                itemCount: parts.length,
                                itemBuilder: (context, index) {
                                  final p = parts[index];
                                  return _ProductGridCard(
                                    part: p,
                                    profile: widget.profile,
                                    compact: true,
                                    showDistanceChips: _activeFilters
                                        .sortByDistanceFromReference,
                                    onTap: () {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (ctx) =>
                                              ProductDetailScreen(part: p),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            if (_hasMoreProducts)
                              Padding(
                                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isDesktopCatalog
                                          ? 360
                                          : double.infinity,
                                    ),
                                    child: SizedBox(
                                      width: isDesktopCatalog
                                          ? null
                                          : double.infinity,
                                      child: ElevatedButton(
                                      onPressed: _isLoadingMore
                                          ? null
                                          : _loadMoreProducts,
                                      child: _isLoadingMore
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Ver más productos'),
                                      ),
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
  });

  final PartModel part;
  final ProfileModel profile;
  final bool compact;
  final bool showDistanceChips;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final importer = (part.ownerBusinessName ?? '').trim();
    final importerLine =
        importer.isNotEmpty ? importer.toUpperCase() : 'SIN IMPORTADOR';
    final locLine = _ownerLocationLine(part);
    final cardPadding = compact
        ? const EdgeInsets.fromLTRB(8, 8, 8, 6)
        : const EdgeInsets.fromLTRB(10, 10, 10, 8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: AppDecorations.cardShadow,
        ),
        child: Padding(
          padding: cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 11,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
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
                      if (part.hasWarranty)
                        Positioned(
                          top: compact ? 4 : 6,
                          right: compact ? 4 : 6,
                          child: const ProductWarrantySeal(compact: true),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Expanded(
                flex: 13,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      part.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ImporterCatalogLogo(
                          storagePath: part.ownerLogoStoragePath,
                          size: compact ? 14 : 16,
                        ),
                        if (part.ownerLogoStoragePath?.trim().isNotEmpty ==
                            true)
                          SizedBox(width: compact ? 4 : 5),
                        Expanded(
                          child: Text(
                            importerLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 9 : 9.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!compact && locLine.isNotEmpty)
                      Text(
                        locLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.1,
                        ),
                      ),
                    if (part.ownerRatingAvg != null &&
                        (part.ownerRatingCount ?? 0) > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: compact ? 10 : 11,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${part.ownerRatingAvg!.toStringAsFixed(1)} (${part.ownerRatingCount})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 9 : 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showDistanceChips) ...[
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(
                            _distanceChipLabel(part),
                            style: TextStyle(
                              fontSize: compact ? 9 : 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          backgroundColor:
                              AppColors.brandBlue.withOpacity(0.1),
                          side: BorderSide(
                            color: AppColors.brandBlue.withOpacity(0.35),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Expanded(
                      child: CatalogProductPriceDisplay(
                        listPriceUsd: part.precio,
                        salePriceUsd: part.salePriceUsd,
                        discountRules: part.discountRules,
                        catalogGrid: true,
                        compact: compact,
                        ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                      ),
                    ),
                    Divider(height: 1, color: AppColors.borderSubtle),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${part.stock} en stock · ${part.minOrderQtyLabelEs}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 10 : 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(bool compact) {
    return ColoredBox(
      color: AppColors.borderSubtle,
      child: Icon(
        Icons.precision_manufacturing_outlined,
        size: compact ? 32 : 40,
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
