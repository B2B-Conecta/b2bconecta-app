import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/catalog_filters.dart';
import '../models/part_model.dart';
import '../models/profile_model.dart';
import '../services/cart_service.dart';
import '../services/geolocator_service.dart';
import '../services/supabase_service.dart';
import 'cart_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/importer_inventory_dashboard.dart';
import '../widgets/motolink_app_bar.dart';
import 'product_detail_screen.dart';

const _kCategoryLabels = <String>[
  'Todos',
  'Frenos',
  'Transmisión',
  'Motor',
  'Eléctrico',
];

const _kCategorySearchTokens = <String, String?>{
  'Todos': null,
  'Frenos': 'freno',
  'Transmisión': 'transmis',
  'Motor': 'motor',
  'Eléctrico': 'eléctric',
};

bool _longDistancePart(PartModel part, ProfileModel profile) {
  final km = part.distanceKmFromReference;
  if (km != null && km >= 120) return true;
  final ae = profile.estado?.trim().toLowerCase();
  final oe = part.ownerEstado?.trim().toLowerCase();
  if (ae != null &&
      ae.isNotEmpty &&
      oe != null &&
      oe.isNotEmpty &&
      ae != oe) {
    return true;
  }
  return false;
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
  String? _selectedOwnerId;
  String _selectedCategoryLabel = 'Todos';

  late final TextEditingController _searchController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late final TextEditingController _ownerEstadoFilterController;
  late final TextEditingController _ownerCiudadFilterController;
  late final Future<List<ImporterOption>> _importersFuture;

  /// Alineado con el precio en ficha (descuento en fase contado).
  bool _aliadoFaseContado = false;

  /// Filtro rápido «Más cercanos a mí» (GPS + orden Haversine).
  bool _closestToMeEnabled = false;
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
      _partsFuture = Future.value(const []);
    } else {
      _importersFuture = Future.value(const []);
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
    return CatalogFilters(
      searchQuery: combined.isEmpty ? null : combined,
      ownerId: _selectedOwnerId,
      ownerEstado: oe.isEmpty ? null : oe,
      ownerCiudad: oc.isEmpty ? null : oc,
      minPrice: minP,
      maxPrice: maxP,
      onlyActiveProducts: true,
      sortReferenceLat: _closestToMeEnabled ? _allySortLat : null,
      sortReferenceLng: _closestToMeEnabled ? _allySortLng : null,
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
      _selectedOwnerId = null;
      _selectedCategoryLabel = 'Todos';
      _closestToMeEnabled = false;
      final la = widget.profile.latitude;
      final lo = widget.profile.longitude;
      _allySortLat = la;
      _allySortLng = lo;
      _activeFilters = CatalogFilters.empty;
      _partsFuture = _fetchProducts(reset: true);
    });
    _refreshCatalogTotal();
  }

  Future<void> _onClosestChipSelected(bool selected) async {
    if (widget.homeRole != AppHomeRole.aliado) return;

    if (!selected) {
      setState(() {
        _closestToMeEnabled = false;
        final la = widget.profile.latitude;
        final lo = widget.profile.longitude;
        _allySortLat = la;
        _allySortLng = lo;
        _activeFilters = _parseFiltersFromControllers();
        _partsFuture = _fetchProducts(reset: true);
      });
      await _refreshCatalogTotal();
      return;
    }

    final pos = await GeolocatorService.getCurrentLatLng();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Active el GPS y conceda permiso de ubicación para ordenar por cercanía.',
          ),
          backgroundColor: Colors.orange.shade900,
        ),
      );
      return;
    }

    try {
      await SupabaseService.updateMyGeolocation(
        latitude: pos.lat,
        longitude: pos.lng,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _closestToMeEnabled = true;
      _allySortLat = pos.lat;
      _allySortLng = pos.lng;
      _activeFilters = _parseFiltersFromControllers();
      _partsFuture = _fetchProducts(reset: true);
    });
    await _refreshCatalogTotal();
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

  Future<void> _openAdvancedFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewPadding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filtros avanzados',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ownerEstadoFilterController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Estado del importador',
                        hintText: 'Ej. Miranda',
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ownerCiudadFilterController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Ciudad del importador',
                        hintText: 'Ej. Valencia',
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Precio mín. (REF)',
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Precio máx. (REF)',
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _clearFilters();
                        Navigator.of(ctx).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFiltersFromUi();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      hintText: 'Repuesto, estado o ciudad del importador…',
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
    );
  }

  /// Fila de chips con scroll horizontal (touch, ratón y trackpad).
  Widget _chipRow({required List<Widget> children}) {
    return SizedBox(
      height: 44,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  ChoiceChip _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.brandOrange,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      backgroundColor: Colors.grey.shade200,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applyFiltersFromUi(),
                    decoration: _searchDecoration(),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.brandOrange,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _openAdvancedFiltersSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        Icons.tune,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _ownerCiudadFilterController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applyFiltersFromUi(),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Ciudad del importador',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(
                  Icons.location_city_outlined,
                  color: Colors.grey.shade600,
                  size: 22,
                ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                  borderSide: const BorderSide(
                    color: AppColors.brandOrange,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _chipRow(
              children: _kCategoryLabels
                  .map(
                    (label) => _filterChip(
                      label: label,
                      selected: _selectedCategoryLabel == label,
                      onSelected: () {
                        setState(() => _selectedCategoryLabel = label);
                        _applyFiltersFromUi();
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<List<ImporterOption>>(
              future: _importersFuture,
              builder: (context, snapshot) {
                final importers = snapshot.data ?? [];
                if (snapshot.hasError) {
                  return Text(
                    'Importadores no disponibles.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IMPORTADOR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _chipRow(
                      children: [
                        _filterChip(
                          label: 'Todos',
                          selected: _selectedOwnerId == null,
                          onSelected: () {
                            setState(() => _selectedOwnerId = null);
                            _applyFiltersFromUi();
                          },
                        ),
                        ...importers.map(
                          (o) => Tooltip(
                            message: o.ubicacionLine,
                            waitDuration: const Duration(milliseconds: 400),
                            child: _filterChip(
                              label: o.businessName,
                              selected: _selectedOwnerId == o.id,
                              onSelected: () {
                                setState(() => _selectedOwnerId = o.id);
                                _applyFiltersFromUi();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_catalogTotal ?? _loadedParts.length} repuestos encontrados',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Más cercanos a mí'),
                      selected: _closestToMeEnabled,
                      onSelected: _onClosestChipSelected,
                      avatar: Icon(
                        Icons.near_me_outlined,
                        size: 18,
                        color: _closestToMeEnabled
                            ? Colors.white
                            : AppColors.brand,
                      ),
                      selectedColor: AppColors.brand,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            _closestToMeEnabled ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (_closestToMeEnabled) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Orden por distancia en línea recta hasta el almacén del importador (cuando hay coordenadas).',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
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
                          // Altura más compacta; en cercanía conservamos un poco más de espacio.
                          childAspectRatio:
                              _activeFilters.sortByDistanceFromReference
                                  ? 0.60
                                  : 0.62,
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
                  aspectRatio: compactDistanceMode ? 1.25 : 1,
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
