import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';

/// Catálogo de un mayorista (Presencia / Reportes). El admin puede ocultarlo.
class AdminPublishedCatalogsSection extends StatefulWidget {
  const AdminPublishedCatalogsSection({
    super.key,
    this.loadImporters,
    this.loadProducts,
    this.countProducts,
    this.loadCatalog,
    this.setProductActive,
    this.focusImporter,
    this.onCloseFocus,
  });

  final Future<List<ImporterOption>> Function()? loadImporters;
  final Future<List<PartModel>> Function({
    required String importerId,
    required int limit,
    required int offset,
  })? loadProducts;
  final Future<int> Function({required String importerId})? countProducts;
  final Future<List<PartModel>> Function({required String importerId})?
      loadCatalog;
  final Future<int> Function({
    required List<String> productIds,
    required bool isActive,
  })? setProductActive;

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
  final _productSearchCtrl = TextEditingController();
  List<ImporterOption> _importers = const [];
  bool _loadingImporters = true;
  String? _importersError;
  ImporterOption? _selected;
  final List<PartModel> _products = [];
  bool _loadingProducts = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _matchingTotal;
  String? _productsError;
  bool _showHidden = false;
  String? _busyProductId;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _productSearchCtrl.addListener(() {
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
    _productSearchCtrl.dispose();
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

  Future<int?> _fetchPublishedCount(String importerId) async {
    final custom = widget.countProducts;
    try {
      if (custom != null) return await custom(importerId: importerId);
      return await SupabaseService.countAdminPublishedCatalog(
        importerId: importerId,
      );
    } catch (_) {
      return null;
    }
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
      _matchingTotal = null;
      _hasMore = true;
      _productsError = null;
      _showHidden = false;
      _productSearchCtrl.clear();
    });
    await _loadProducts(reset: true);
  }

  Future<void> _selectVisibility(bool hidden) async {
    if (_showHidden == hidden) return;
    setState(() {
      _showHidden = hidden;
      _productSearchCtrl.clear();
    });
    await _loadProducts(reset: true);
  }

  Future<List<PartModel>> _fetchCatalog(String importerId) {
    final custom = widget.loadCatalog;
    if (custom != null) return custom(importerId: importerId);
    return SupabaseService.ownerListImporterCatalog(importerId: importerId);
  }

  Future<int> _setActive({
    required List<String> productIds,
    required bool isActive,
  }) {
    final custom = widget.setProductActive;
    if (custom != null) {
      return custom(productIds: productIds, isActive: isActive);
    }
    return SupabaseService.ownerSetImporterProductsActive(
      productIds: productIds,
      isActive: isActive,
    );
  }

  Future<void> _toggleVisibility(PartModel part) async {
    if (_busyProductId != null) return;
    final hide = part.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          hide ? 'Ocultar producto' : 'Mostrar producto',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AdminUsersChrome.titleColor,
          ),
        ),
        content: Text(
          hide
              ? '«${part.nombre}» deja de verse en el catálogo de las tiendas. '
                  'El proveedor conserva el SKU.'
              : '«${part.nombre}» vuelve a verse en el catálogo de las tiendas.',
          style: TextStyle(fontSize: 13, color: AdminUsersChrome.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminUsersChrome.brand,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hide ? 'Ocultar' : 'Mostrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyProductId = part.id);
    try {
      await _setActive(productIds: [part.id], isActive: !hide);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hide ? 'Producto oculto.' : 'Producto visible.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadProducts(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
  }

  Future<void> _loadProducts({required bool reset}) async {
    final selected = _selected;
    if (selected == null) return;
    if (reset) {
      setState(() {
        _loadingProducts = true;
        _productsError = null;
        _products.clear();
        _matchingTotal = null;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final List<PartModel> batch;
      int? matching = _matchingTotal;
      if (_showHidden) {
        final rows = await _fetchCatalog(selected.id);
        batch = rows.where((part) => !part.isActive).toList();
        matching = batch.length;
      } else {
        final countFuture =
            reset ? _fetchPublishedCount(selected.id) : null;
        batch = await _fetchProducts(
          importerId: selected.id,
          limit: AdminPublishedCatalogsSection.pageSize,
          offset: reset ? 0 : _products.length,
        );
        if (countFuture != null) matching = await countFuture;
      }
      if (!mounted) return;
      final loaded = (reset ? 0 : _products.length) + batch.length;
      setState(() {
        if (reset) {
          _products
            ..clear()
            ..addAll(batch);
          _matchingTotal = matching;
        } else {
          _products.addAll(batch);
        }
        _hasMore = !_showHidden &&
            listPagerHasMore(
              loaded: loaded,
              batchLength: batch.length,
              fetchSize: AdminPublishedCatalogsSection.pageSize,
              matching: matching,
            );
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

  List<PartModel> get _visibleProducts {
    final q = _productSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) {
      final name = p.nombre.toLowerCase();
      final sku = (p.sku ?? '').toLowerCase();
      final cat = (p.category ?? '').toLowerCase();
      return name.contains(q) || sku.contains(q) || cat.contains(q);
    }).toList();
  }

  void _goBack() {
    if (widget.onCloseFocus != null) {
      widget.onCloseFocus!();
      return;
    }
    setState(() {
      _selected = null;
      _products.clear();
      _matchingTotal = null;
      _productsError = null;
      _showHidden = false;
      _productSearchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final title = selected != null
        ? selected.businessName
        : (widget.focusImporter != null
            ? 'Catálogo del mayorista'
            : 'Catálogos publicados');
    final subtitle = selected != null
        ? (_matchingTotal == null
            ? (_showHidden
                ? 'Productos ocultos del mayorista.'
                : 'Productos publicados del mayorista.')
            : (_showHidden
                ? '$_matchingTotal oculto${_matchingTotal == 1 ? '' : 's'}.'
                : '$_matchingTotal publicado${_matchingTotal == 1 ? '' : 's'}.'))
        : 'Productos publicados u ocultos del mayorista.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selected != null)
                IconButton(
                  tooltip: widget.onCloseFocus != null ? 'Volver' : 'Cambiar',
                  visualDensity: VisualDensity.compact,
                  onPressed: _goBack,
                  icon: LucideIcon(
                    LucideGlyph.arrowLeft,
                    size: 18,
                    color: AdminUsersChrome.titleColor,
                  ),
                )
              else
                const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: selected != null ? 8 : 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AdminUsersChrome.titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminUsersChrome.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected != null)
                IconButton(
                  tooltip: 'Actualizar',
                  visualDensity: VisualDensity.compact,
                  onPressed: _loadingProducts
                      ? null
                      : () => _loadProducts(reset: true),
                  icon: LucideIcon(
                    LucideGlyph.refreshCw,
                    size: 16,
                    color: AdminUsersChrome.muted,
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loadingImporters) {
      return Center(
        key: Key('admin-catalogs-importers-loading'),
        child: CircularProgressIndicator(color: AdminUsersChrome.brand),
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
    return _catalog();
  }

  Widget _picker() {
    final theme = B2BThemeExtension.of(context);
    final rows = _visibleImporters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: AdminUsersChrome.field(
              label: 'Buscar',
              hint: 'Mayorista por nombre…',
            ).copyWith(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 10, right: 6),
                child: LucideIcon(
                  LucideGlyph.search,
                  size: 16,
                  color: AdminUsersChrome.muted,
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    'Ningún mayorista coincide.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminUsersChrome.muted,
                    ),
                  ),
                )
              : PagedItems(
                  items: rows,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  separator: 0,
                  itemBuilder: (o) {
                    return Material(
                      color: theme.surfaceCard,
                      child: InkWell(
                        onTap: () => _selectImporter(o),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AdminUsersChrome.border,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.businessName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AdminUsersChrome.titleColor,
                                  ),
                                ),
                              ),
                              LucideIcon(
                                LucideGlyph.chevronRight,
                                size: 16,
                                color: AdminUsersChrome.brand,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _catalog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              _CatalogPill(
                label: 'Publicados',
                selected: !_showHidden,
                glyph: LucideGlyph.store,
                onTap: () => _selectVisibility(false),
              ),
              const SizedBox(width: 6),
              _CatalogPill(
                label: 'Ocultos',
                selected: _showHidden,
                glyph: LucideGlyph.package,
                onTap: () => _selectVisibility(true),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: TextField(
            controller: _productSearchCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: AdminUsersChrome.field(
              label: 'Buscar producto',
              hint: 'Nombre, SKU o categoría…',
            ).copyWith(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 10, right: 6),
                child: LucideIcon(
                  LucideGlyph.search,
                  size: 16,
                  color: AdminUsersChrome.muted,
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
        ),
        Expanded(child: _productBody()),
      ],
    );
  }

  Widget _productBody() {
    if (_loadingProducts && _products.isEmpty) {
      return Center(
        key: Key('admin-catalogs-products-loading'),
        child: CircularProgressIndicator(color: AdminUsersChrome.brand),
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
      return Center(
        key: const Key('admin-catalogs-empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _showHidden
                ? 'Este mayorista no tiene productos ocultos.'
                : 'Este mayorista no tiene productos publicados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AdminUsersChrome.muted,
            ),
          ),
        ),
      );
    }

    final visible = _visibleProducts;
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ningún producto coincide con la búsqueda.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AdminUsersChrome.muted),
          ),
        ),
      );
    }

    return PagedItems(
      items: visible,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      separator: 0,
      hasMore: _hasMore && _productSearchCtrl.text.trim().isEmpty,
      totalCount: _productSearchCtrl.text.trim().isEmpty
          ? _matchingTotal
          : visible.length,
      onNeedMore: _loadingMore || _productSearchCtrl.text.trim().isNotEmpty
          ? null
          : () => _loadProducts(reset: false),
      itemBuilder: (part) => _PublishedProductRow(
        part: part,
        importerName: _selected?.businessName ?? '',
        zebra: part.id.hashCode.isOdd,
        busy: _busyProductId == part.id,
        enabled: _busyProductId == null,
        onToggleVisibility: () => _toggleVisibility(part),
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
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AdminUsersChrome.muted,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AdminUsersChrome.brand,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogPill extends StatelessWidget {
  const _CatalogPill({
    required this.label,
    required this.selected,
    required this.glyph,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final LucideGlyph glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final bg = selected ? theme.brand : theme.brandContainer;
    final fg = selected ? theme.surfaceCard : theme.brand;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(glyph, size: 13, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishedProductRow extends StatelessWidget {
  const _PublishedProductRow({
    required this.part,
    required this.importerName,
    required this.zebra,
    required this.busy,
    required this.enabled,
    required this.onToggleVisibility,
  });

  final PartModel part;
  final String importerName;
  final bool zebra;
  final bool busy;
  final bool enabled;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final sku = part.sku?.trim();
    final category = part.category?.trim();
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Material(
      color: zebra ? AdminUsersChrome.zebra : AdminUsersChrome.rowEven,
      child: InkWell(
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
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AdminUsersChrome.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: part.coverImageUrl != null &&
                          part.coverImageUrl!.isNotEmpty
                      ? Image.network(
                          part.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ThumbFallback(),
                        )
                      : const _ThumbFallback(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminUsersChrome.titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (sku != null && sku.isNotEmpty) 'SKU $sku',
                        if (category != null && category.isNotEmpty) category,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AdminUsersChrome.muted,
                      ),
                    ),
                    if (!wide) ...[
                      const SizedBox(height: 4),
                      _CompactPrice(
                        listPriceUsd: part.precio,
                        salePriceUsd: part.salePriceUsd,
                        ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                      ),
                    ],
                  ],
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: _CompactPrice(
                    listPriceUsd: part.precio,
                    salePriceUsd: part.salePriceUsd,
                    ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                    alignEnd: true,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              _ActionPill(
                label: part.isActive ? 'Ocultar' : 'Mostrar',
                busy: busy,
                enabled: enabled,
                onTap: onToggleVisibility,
              ),
              const SizedBox(width: 4),
              LucideIcon(
                LucideGlyph.chevronRight,
                size: 16,
                color: AdminUsersChrome.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminUsersChrome.zebra,
      child: Center(
        child: LucideIcon(
          LucideGlyph.image,
          size: 16,
          color: AdminUsersChrome.muted,
        ),
      ),
    );
  }
}

class _CompactPrice extends StatefulWidget {
  const _CompactPrice({
    required this.listPriceUsd,
    this.salePriceUsd,
    this.ownerPagoSoloDivisas = false,
    this.alignEnd = false,
  });

  final double listPriceUsd;
  final double? salePriceUsd;
  final bool ownerPagoSoloDivisas;
  final bool alignEnd;

  @override
  State<_CompactPrice> createState() => _CompactPriceState();
}

class _CompactPriceState extends State<_CompactPrice> {
  double? _rate;

  @override
  void initState() {
    super.initState();
    final cached = BcvBasePrice.cachedRate;
    if (cached != null && cached > 0) {
      _rate = cached;
    } else {
      BcvBasePrice.currentRate().then((rate) {
        if (mounted) setState(() => _rate = rate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.ownerPagoSoloDivisas ? 'USD' : 'REF';
    final sale = widget.salePriceUsd;
    final hasSale =
        sale != null && sale > 0 && sale < widget.listPriceUsd;
    final main = hasSale ? sale : widget.listPriceUsd;
    final bs = BcvBasePrice.bsForRef(main, _rate);

    return Align(
      alignment:
          widget.alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: widget.alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${main.toStringAsFixed(2)} $currency',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AdminUsersChrome.titleColor,
              height: 1.15,
            ),
          ),
          if (hasSale)
            Text(
              '${widget.listPriceUsd.toStringAsFixed(2)} $currency',
              style: TextStyle(
                fontSize: 11,
                color: AdminUsersChrome.muted,
                decoration: TextDecoration.lineThrough,
                height: 1.2,
              ),
            ),
          if (!widget.ownerPagoSoloDivisas)
            Text(
              bs == null ? 'Bs …' : formatBsLabel(bs),
              style: TextStyle(
                fontSize: 11,
                color: AdminUsersChrome.muted,
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AdminUsersChrome.brand,
        ),
      );
    }
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.brandContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? AdminUsersChrome.brand
                  : AdminUsersChrome.muted,
            ),
          ),
        ),
      ),
    );
  }
}
