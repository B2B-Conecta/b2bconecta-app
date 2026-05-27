import 'package:flutter/material.dart';

import '../models/aliado_catalog_filters_draft.dart';
import '../models/app_home_role.dart';
import '../models/catalog_filters.dart';
import '../models/catalog_sort_mode.dart';
import '../models/promo_campaign_model.dart';
import '../models/part_model.dart';
import '../models/profile_model.dart';
import '../services/cart_service.dart';
import '../services/geolocator_service.dart';
import '../services/supabase_service.dart';
import 'cart_screen.dart';
import '../theme/app_theme.dart';
import '../utils/promo_popup_frequency.dart';
import '../widgets/aliado_catalog_filters_sheet.dart';
import '../widgets/aliado_promo_campaign_widgets.dart';
import '../widgets/importer_inventory_dashboard.dart';
import '../widgets/motolink_app_bar.dart';
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
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final VoidCallback? onNotificationTap;
  final int unreadNotifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _kCrossAxisCount = 2;
  static const int _kPageSize = _kCrossAxisCount * 3;

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

  /// Alineado con el precio en ficha (descuento en fase contado).
  bool _aliadoFaseContado = false;

  CatalogSortMode _catalogSortMode = CatalogSortMode.recommended;
  double? _minOwnerRatingAvg;
  int? _minOwnerRatingCount;
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
      _aliadoFaseContado = widget.profile.esAliadoEnFaseContado;
      SupabaseService.fetchMyProfile().then((p) {
        if (!mounted) return;
        setState(() {
          _aliadoFaseContado = p?.esAliadoEnFaseContado ?? false;
        });
      });
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
          backgroundColor: Colors.orange.shade900,
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
      limit: _kPageSize,
      offset: _loadedParts.length,
      filters: _activeFilters,
    );

    if (nextBatch.length < _kPageSize) {
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
  }) {
    return InputDecoration(
      hintText: 'Buscar repuesto…',
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandOrange, width: 1.5),
      ),
      suffixIcon: onOpenFilters == null
          ? (_searchController.text.trim().isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _applyFiltersFromUi();
                  },
                ))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.trim().isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _applyFiltersFromUi();
                    },
                  ),
                IconButton(
                  tooltip: 'Filtros',
                  onPressed: onOpenFilters,
                  icon: Badge(
                    isLabelVisible: filterBadge > 0,
                    label: Text('$filterBadge'),
                    backgroundColor: AppColors.brandOrange,
                    child: Icon(
                      Icons.tune,
                      color: filterBadge > 0
                          ? AppColors.brandOrange
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
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
      backgroundColor: AppColors.brandOrange.withOpacity(0.12),
      side: BorderSide(color: AppColors.brandOrange.withOpacity(0.35)),
      labelStyle: const TextStyle(
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
    final appBar = MotolinkAppBar(
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
                              color: AppColors.brandOrange,
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
                const Text(
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
                  'Los importadores solo ven pedidos que MotoLink haya validado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.grey.shade700,
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
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
              if (promos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _openActivePromotionsSheet(promos),
                      icon: const Icon(Icons.campaign_outlined, size: 18),
                      label: Text('Promociones (${promos.length})'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandOrange,
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  '${_catalogTotal ?? _loadedParts.length} repuestos encontrados',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
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
                          color: Colors.grey.shade800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
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
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _kCrossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          // cross / main = ancho / alto del hijo. Menor ratio = celdas más altas
                          // (evita overflow al mostrar importador, ubicación, rating y precio).
                          childAspectRatio:
                              _activeFilters.sortByDistanceFromReference
                                  ? 0.54
                                  : 0.56,
                        ),
                        itemCount: parts.length,
                        itemBuilder: (context, index) {
                          final p = parts[index];
                          return _ProductGridCard(
                            part: p,
                            profile: widget.profile,
                            showDistanceChips:
                                _activeFilters.sortByDistanceFromReference,
                            faseContadoAliado: _aliadoFaseContado,
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _isLoadingMore ? null : _loadMoreProducts,
                            child: _isLoadingMore
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Ver mas productos'),
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
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  const _ProductGridCard({
    required this.part,
    required this.profile,
    this.showDistanceChips = false,
    this.faseContadoAliado = false,
    this.onTap,
  });

  final PartModel part;
  final ProfileModel profile;
  final bool showDistanceChips;
  final bool faseContadoAliado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final compactDistanceMode = showDistanceChips;
    final importer = (part.ownerBusinessName ?? '').trim();
    final importerLine =
        importer.isNotEmpty ? importer.toUpperCase() : 'SIN IMPORTADOR';
    final locLine = _ownerLocationLine(part);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppDecorations.cardShadow,
        ),
        child: Padding(
          padding: EdgeInsets.all(compactDistanceMode ? 6 : 8),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: compactDistanceMode ? 1.25 : 1.05,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Hero(
                      tag: ProductDetailScreen.heroImageTag(part),
                      child: part.imagenUrl != null &&
                              part.imagenUrl!.isNotEmpty
                          ? Image.network(
                              part.imagenUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  importerLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compactDistanceMode ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (locLine.isNotEmpty) ...[
                  SizedBox(height: compactDistanceMode ? 1 : 2),
                  Text(
                    locLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compactDistanceMode ? 9.5 : 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (part.ownerRatingAvg != null &&
                    (part.ownerRatingCount ?? 0) > 0) ...[
                  SizedBox(height: compactDistanceMode ? 2 : 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: compactDistanceMode ? 12 : 13,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${part.ownerRatingAvg!.toStringAsFixed(1)} (${part.ownerRatingCount})',
                        style: TextStyle(
                          fontSize: compactDistanceMode ? 9.5 : 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
                if (showDistanceChips) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 28,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          label: Text(
                            _distanceChipLabel(part),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          backgroundColor: AppColors.brandBlue.withOpacity(0.1),
                          side:
                              BorderSide(color: AppColors.brandBlue.withOpacity(0.35)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  height: 18,
                  child: Text(
                    part.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                ),
                Text(
                  '${part.precioUnitarioParaAliado(faseContado: faseContadoAliado).toStringAsFixed(2)} REF',
                  style: TextStyle(
                    fontSize: compactDistanceMode ? 15.5 : 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${part.stock} en stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compactDistanceMode ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.precision_manufacturing_outlined,
        size: 40,
        color: Colors.grey.shade500,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppDecorations.cardShadow,
        ),
        child: const Row(
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
