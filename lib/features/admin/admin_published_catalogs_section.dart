import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';

/// Reportes: catálogo publicado de un mayorista. Solo lectura.
class AdminPublishedCatalogsSection extends StatefulWidget {
  const AdminPublishedCatalogsSection({
    super.key,
    this.loadImporters,
    this.loadProducts,
    this.focusImporter,
    this.onCloseFocus,
  });

  final Future<List<ImporterOption>> Function()? loadImporters;
  final Future<List<PartModel>> Function({
    required String importerId,
    required int limit,
    required int offset,
  })? loadProducts;

  /// Abre directo el catálogo de un mayorista, sin el buscador de todos.
  final ImporterOption? focusImporter;
  final VoidCallback? onCloseFocus;

  static const pageSize = 40;

  @override
  State<AdminPublishedCatalogsSection> createState() =>
      _AdminPublishedCatalogsSectionState();
}

class _AdminPublishedCatalogsSectionState
    extends State<AdminPublishedCatalogsSection> {
  final _searchCtrl = TextEditingController();
  List<ImporterOption> _importers = const [];
  bool _loadingImporters = true;
  String? _importersError;
  ImporterOption? _selected;
  final List<PartModel> _products = [];
  bool _loadingProducts = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _productsError;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    final focus = widget.focusImporter;
    if (focus != null) {
      _selected = focus;
      _loadingImporters = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProducts(reset: true);
      });
    } else {
      _loadImporters();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<ImporterOption>> _fetchImporters() {
    final custom = widget.loadImporters;
    if (custom != null) return custom();
    return SupabaseService.fetchImporterOptions();
  }

  Future<List<PartModel>> _fetchProducts({
    required String importerId,
    required int limit,
    required int offset,
  }) {
    final custom = widget.loadProducts;
    if (custom != null) {
      return custom(importerId: importerId, limit: limit, offset: offset);
    }
    return SupabaseService.fetchAdminPublishedCatalog(
      importerId: importerId,
      limit: limit,
      offset: offset,
    );
  }

  Future<void> _loadImporters() async {
    setState(() {
      _loadingImporters = true;
      _importersError = null;
    });
    try {
      final rows = await _fetchImporters();
      if (!mounted) return;
      setState(() {
        _importers = rows;
        _loadingImporters = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importersError = e.toString();
        _loadingImporters = false;
      });
    }
  }

  Future<void> _selectImporter(ImporterOption option) async {
    setState(() {
      _selected = option;
      _products.clear();
      _hasMore = true;
      _productsError = null;
    });
    await _loadProducts(reset: true);
  }

  Future<void> _loadProducts({required bool reset}) async {
    final selected = _selected;
    if (selected == null) return;
    if (reset) {
      setState(() {
        _loadingProducts = true;
        _productsError = null;
        _products.clear();
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final batch = await _fetchProducts(
        importerId: selected.id,
        limit: AdminPublishedCatalogsSection.pageSize,
        offset: reset ? 0 : _products.length,
      );
      if (!mounted) return;
      setState(() {
        _products.addAll(batch);
        _hasMore = batch.length >= AdminPublishedCatalogsSection.pageSize;
        _loadingProducts = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productsError = e.toString();
        _loadingProducts = false;
        _loadingMore = false;
      });
    }
  }

  List<ImporterOption> get _visibleImporters {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _importers;
    return _importers.where((o) {
      return o.businessName.toLowerCase().contains(q) ||
          o.id.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Catálogos publicados de mayoristas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loadingImporters) {
      return const Center(
        key: Key('admin-catalogs-importers-loading'),
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_importersError != null && _importers.isEmpty) {
      return _message(
        key: const Key('admin-catalogs-importers-error'),
        text: 'No se pudo cargar la lista de mayoristas.',
        onRetry: _loadImporters,
      );
    }
    final selected = _selected;
    if (selected == null) return _picker();
    return _catalog(selected);
  }

  Widget _picker() {
    final rows = _visibleImporters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Buscar mayorista por nombre',
              isDense: true,
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('Ningún mayorista coincide.'))
              : PagedItems(
                  items: rows,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  separator: 8,
                  itemBuilder: (o) {
                    return Material(
                      color: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.borderSubtle),
                      ),
                      child: ListTile(
                        title: Text(o.businessName),
                        subtitle: Text(o.id),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectImporter(o),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _catalog(ImporterOption selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected.businessName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (widget.onCloseFocus != null) {
                    widget.onCloseFocus!();
                    return;
                  }
                  setState(() {
                    _selected = null;
                    _products.clear();
                    _productsError = null;
                  });
                },
                child: Text(widget.onCloseFocus != null ? 'Volver' : 'Cambiar'),
              ),
            ],
          ),
        ),
        Expanded(child: _productBody()),
      ],
    );
  }

  Widget _productBody() {
    if (_loadingProducts && _products.isEmpty) {
      return const Center(
        key: Key('admin-catalogs-products-loading'),
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_productsError != null && _products.isEmpty) {
      return _message(
        key: const Key('admin-catalogs-products-error'),
        text: 'No se pudo cargar el catálogo.',
        onRetry: () => _loadProducts(reset: true),
      );
    }
    if (_products.isEmpty) {
      return const Center(
        key: Key('admin-catalogs-empty'),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Este mayorista no tiene productos publicados.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return PagedItems(
      items: _products,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      separator: 8,
      hasMore: _hasMore,
      onNeedMore: _loadingMore ? null : () => _loadProducts(reset: false),
      itemBuilder: (part) => _PublishedProductTile(
        part: part,
        importerName: _selected?.businessName ?? '',
      ),
    );
  }

  Widget _message({
    required Key key,
    required String text,
    required VoidCallback onRetry,
  }) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedProductTile extends StatelessWidget {
  const _PublishedProductTile({
    required this.part,
    required this.importerName,
  });

  final PartModel part;
  final String importerName;

  @override
  Widget build(BuildContext context) {
    final sku = part.sku?.trim();
    final category = part.category?.trim();
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final named = part.ownerBusinessName?.trim().isNotEmpty == true
              ? part
              : part.copyWith(ownerBusinessName: importerName);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProductDetailScreen(part: named),
            ),
          );
        },
        child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: part.coverImageUrl != null &&
                        part.coverImageUrl!.isNotEmpty
                    ? Image.network(
                        part.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: AppColors.surfaceTinted,
                          child: const Icon(Icons.image_outlined),
                        ),
                      )
                    : ColoredBox(
                        color: AppColors.surfaceTinted,
                        child: const Icon(Icons.image_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (sku != null && sku.isNotEmpty)
                    Text(
                      'SKU $sku',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (category != null && category.isNotEmpty)
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  const SizedBox(height: 4),
                  CatalogProductPriceDisplay(
                    listPriceUsd: part.precio,
                    salePriceUsd: part.salePriceUsd,
                    discountRules: part.discountRules,
                    compact: true,
                    showPromotionChips: false,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.brand),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
