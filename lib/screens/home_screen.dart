import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/part_model.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';

const _kCorporateRed = Color(0xFFE31B23);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _kPageSize = 5;
  late Future<List<PartModel>> _partsFuture;
  final List<PartModel> _loadedParts = <PartModel>[];
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _partsFuture = _fetchProducts(reset: true);
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
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
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
                  'Muestra: ${_loadedParts.length}',
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
              'Se cargan 5 productos por bloque.',
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
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: parts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final part = parts[index];
                          return _PartCard(part: part);
                        },
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

class _PartCard extends StatelessWidget {
  const _PartCard({required this.part});

  final PartModel part;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 108,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: part.imagenUrl != null && part.imagenUrl!.isNotEmpty
                      ? Image.network(
                          part.imagenUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (part.descripcion != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      part.descripcion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '\$${part.precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _kCorporateRed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${part.stock}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (part.compatibilidad != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Compatibilidad: ${part.compatibilidad}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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

  Widget _placeholder() {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Icon(Icons.precision_manufacturing_outlined,
          size: 40, color: Colors.grey.shade500),
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
