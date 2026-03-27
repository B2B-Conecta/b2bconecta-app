import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/part_model.dart';
import '../services/supabase_service.dart';

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

  @override
  void initState() {
    super.initState();
    _partsFuture = _fetchProducts(reset: true);
    _refreshCatalogTotal();
  }

  Future<void> _refreshCatalogTotal() async {
    try {
      final n = await SupabaseService.fetchProductsCount();
      if (!mounted) return;
      setState(() => _catalogTotal = n);
    } catch (_) {
      if (!mounted) return;
      setState(() => _catalogTotal = null);
    }
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
    await Supabase.instance.client.auth.signOut();
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
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: _kCorporateRed),
            label: const Text(
              'Cerrar sesión',
              style: TextStyle(
                color: _kCorporateRed,
                fontWeight: FontWeight.w600,
              ),
            ),
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
              'Se cargan 6 productos por bloque (2 filas × 3 columnas).',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
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
                          'No hay repuestos disponibles.',
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
                              return _ProductGridCard(part: parts[index]);
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
                            onPressed: _isLoadingMore ? null : _loadMoreProducts,
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
                              _isLoadingMore ? 'Cargando...' : 'Ver mas productos',
                              style: const TextStyle(fontWeight: FontWeight.w700),
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
  const _ProductGridCard({required this.part});

  final PartModel part;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
