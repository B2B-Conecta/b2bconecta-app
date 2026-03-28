import 'package:flutter/material.dart';

import '../models/catalog_filters.dart';
import '../models/part_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'account_settings_screen.dart';
import 'product_detail_screen.dart';
import 'profile_setup_screen.dart';

const _kCorporateRed = Color(0xFFE31B23);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 2 filas × 3 columnas por bloque de carga.
  static const int _kCrossAxisCount = 3;
  static const int _kPageSize = _kCrossAxisCount * 2;
  late Future<List<PartModel>> _partsFuture;
  final List<PartModel> _loadedParts = <PartModel>[];
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;
  int? _catalogTotal;
  CatalogFilters _activeFilters = CatalogFilters.empty;
  String? _selectedOwnerId;

  late final TextEditingController _searchController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late final Future<List<ImporterOption>> _importersFuture;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _minPriceController = TextEditingController();
    _maxPriceController = TextEditingController();
    _importersFuture = SupabaseService.fetchImporterOptions();
    _partsFuture = _fetchProducts(reset: true);
    _refreshCatalogTotal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
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
    final q = _searchController.text.trim();
    return CatalogFilters(
      searchQuery: q.isEmpty ? null : q,
      ownerId: _selectedOwnerId,
      minPrice: minP,
      maxPrice: maxP,
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
    setState(() {
      _selectedOwnerId = null;
      _activeFilters = CatalogFilters.empty;
      _partsFuture = _fetchProducts(reset: true);
    });
    _refreshCatalogTotal();
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

  Future<void> _signOut() async {
    await AuthService.signOut();
  }

  Future<void> _openProfileEdit() async {
    final profile = await SupabaseService.fetchMyProfile();
    if (!mounted) return;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('No se encontró tu perfil. Vuelve a iniciar sesión.'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => ProfileSetupScreen(
          initial: profile,
          isEditing: true,
          onProfileComplete: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _openAccountSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AccountSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'MotoLink Pro',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) async {
              switch (value) {
                case 0:
                  await _openProfileEdit();
                  break;
                case 1:
                  await _openAccountSettings();
                  break;
                case 2:
                  await _signOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<int>(
                value: 0,
                child: ListTile(
                  leading: Icon(Icons.business_outlined),
                  title: Text('Editar perfil empresa'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<int>(
                value: 1,
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Cuenta y seguridad'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<int>(
                value: 2,
                child: ListTile(
                  leading: Icon(Icons.logout, color: _kCorporateRed),
                  title: Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: _kCorporateRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Repuestos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _catalogTotal != null
                      ? 'Mostrando ${_loadedParts.length} de $_catalogTotal'
                      : 'Mostrando ${_loadedParts.length}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Se cargan 6 productos por bloque (2 filas × 3 columnas). Puedes filtrar por nombre, importador y precio.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: FutureBuilder<List<ImporterOption>>(
              future: _importersFuture,
              builder: (context, snapshot) {
                final importers = snapshot.data ?? [];
                if (snapshot.hasError) {
                  return Text(
                    'No se pudieron cargar los importadores. El filtro por importador no estará disponible.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _applyFiltersFromUi(),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre...',
                        prefixIcon: const Icon(Icons.search,
                            size: 22, color: Colors.black45),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: _selectedOwnerId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Importador',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos'),
                        ),
                        ...importers.map(
                          (o) => DropdownMenuItem<String?>(
                            value: o.id,
                            child: Text(
                              o.businessName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        _selectedOwnerId = v;
                        _applyFiltersFromUi();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Precio min (USD)',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _maxPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Precio max (USD)',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clearFilters,
                            child: const Text('Limpiar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _kCorporateRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _applyFiltersFromUi,
                            child: const Text('Aplicar filtros'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PartModel>>(
              future: _partsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
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
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _kCrossAxisCount,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              // Ancho/alto de celda: valor más bajo = más altura (evita overflow del texto).
                              childAspectRatio: 0.62,
                            ),
                            itemCount: parts.length,
                            itemBuilder: (context, index) {
                              final p = parts[index];
                              return _ProductGridCard(
                                part: p,
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
                      ),
                    ),
                    if (_hasMoreProducts)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isLoadingMore ? null : _loadMoreProducts,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kCorporateRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isLoadingMore
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.expand_more),
                            label: Text(
                              _isLoadingMore
                                  ? 'Cargando...'
                                  : 'Ver mas productos',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
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
      ),
    );
  }
}

/// Tarjeta compacta para rejilla 3×N (centrada en el catálogo).
class _ProductGridCard extends StatelessWidget {
  const _ProductGridCard({required this.part, this.onTap});

  final PartModel part;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Hero(
                    tag: ProductDetailScreen.heroImageTag(part),
                    child: part.imagenUrl != null && part.imagenUrl!.isNotEmpty
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
              const SizedBox(height: 4),
              Expanded(
                flex: 5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (part.ownerBusinessName != null &&
                          part.ownerBusinessName!.isNotEmpty)
                        Text(
                          part.ownerBusinessName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        )
                      else if (part.ownerId != null)
                        Text(
                          'Sin importador',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${part.precio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _kCorporateRed,
                        ),
                      ),
                      Text(
                        'Stock ${part.stock}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (part.compatibilidad != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          part.compatibilidad!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
        size: 22,
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: _kCorporateRed,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Cargando repuestos...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
