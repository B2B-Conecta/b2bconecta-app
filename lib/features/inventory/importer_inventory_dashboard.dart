import 'package:flutter/material.dart';
import 'package:motolink_pro_app/features/catalog/catalog_browse_layout.dart';

import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_share_link.dart';
import 'package:motolink_pro_app/features/catalog/product_share_sheet.dart';
import 'package:motolink_pro_app/features/catalog/share_qr_sheet.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'importer_product_edit_screen.dart';
import 'catalog_import_orchestrator.dart';
import 'excel_catalog_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'importer_bulk_photos_screen.dart';
import 'importer_flexible_import_screen.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/excel_file_export.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'importer_inventory_layout.dart';
import 'inventory_product_tile.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'product_delete_outcome_sheet.dart';
import 'product_delete_result.dart';
import 'product_images.dart';

enum _InventorySelectionMode { none, visibility, delete }

/// Gestión de productos, precios, stock y publicación del importador.
class ImporterInventoryDashboard extends StatefulWidget {
  const ImporterInventoryDashboard({super.key});

  @override
  State<ImporterInventoryDashboard> createState() =>
      _ImporterInventoryDashboardState();
}

class _ImporterInventoryDashboardState
    extends State<ImporterInventoryDashboard> {
  final _searchController = TextEditingController();
  final _inventoryScrollController = ScrollController();
  Future<InventoryMetrics>? _metricsFuture;
  Future<List<PartModel>>? _partsFuture;
  final List<PartModel> _loadedParts = <PartModel>[];
  int _productPageIndex = 0;
  int _productPageSize = listPageSizeOptions.first;
  int _inventoryRequestId = 0;
  bool _hasMoreInventory = true;
  bool _loadingMoreInventory = false;
  String _categoryFilter = 'Todas';
  bool _filterLowStock = false;
  bool _filterOutOfStock = false;
  bool _filterHidden = false;
  bool _filterActiveOnly = false;
  ProductPhotoListFilter _photoFilter = ProductPhotoListFilter.all;
  _InventorySelectionMode _selectionMode = _InventorySelectionMode.none;
  bool _pagoSoloDivisas = false;
  ProfileModel? _priorityProfile;
  final Set<String> _selectedIds = <String>{};
  final Set<String> _togglingProductIds = <String>{};

  bool get _inSelectionMode => _selectionMode != _InventorySelectionMode.none;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadImporterPagoPolicy();
    MainShellTabController.registerImporterInventoryReload(_reload);
    MainShellTabController.importerInventoryRequest
        .addListener(_onInventoryRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onInventoryRequest());
  }

  Future<void> _loadImporterPagoPolicy() async {
    try {
      final profile = await SupabaseService.fetchMyProfile();
      if (!mounted) return;
      setState(() {
        _pagoSoloDivisas = profile?.pagoSoloDivisas ?? false;
        _priorityProfile = profile;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    MainShellTabController.registerImporterInventoryReload(null);
    MainShellTabController.importerInventoryRequest
        .removeListener(_onInventoryRequest);
    _searchController.dispose();
    _inventoryScrollController.dispose();
    super.dispose();
  }

  void _reload() => _reloadInventory();

  double? _keptInventoryOffset;

  void _reloadInventory(
      {bool preserveScroll = false, bool refreshMetrics = true}) {
    final kept = preserveScroll && _inventoryScrollController.hasClients
        ? _inventoryScrollController.offset
        : null;
    _keptInventoryOffset = kept;
    setState(() {
      if (!preserveScroll) {
        _loadedParts.clear();
      }
      _productPageIndex = 0;
      _hasMoreInventory = true;
      if (refreshMetrics) {
        _metricsFuture = SupabaseService.fetchMyInventoryMetrics();
      }
      _partsFuture = _fetchInventoryPage(
        reset: true,
        preserveScroll: preserveScroll,
      );
    });
  }

  void _restoreInventoryOffset() {
    final kept = _keptInventoryOffset;
    if (kept == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_inventoryScrollController.hasClients) return;
      final max = _inventoryScrollController.position.maxScrollExtent;
      _inventoryScrollController.jumpTo(kept.clamp(0.0, max));
      _keptInventoryOffset = null;
    });
  }

  Future<List<PartModel>> _fetchInventoryPage({
    required bool reset,
    bool preserveScroll = false,
  }) async {
    final requestId = reset ? ++_inventoryRequestId : _inventoryRequestId;
    if (reset && !preserveScroll) {
      _loadedParts.clear();
      _hasMoreInventory = true;
      if (_inventoryScrollController.hasClients) {
        _inventoryScrollController.jumpTo(0);
      }
    }
    if (reset && preserveScroll) {
      _hasMoreInventory = true;
    }
    if (!_hasMoreInventory) {
      return List<PartModel>.unmodifiable(_loadedParts);
    }

    final batch = await SupabaseService.fetchMyInventory(
      limit: ImporterInventoryLayout.pageSize,
      offset: reset ? 0 : _loadedParts.length,
      searchQuery: _searchController.text,
      category: _categoryFilter,
      onlyLowStock: _filterLowStock,
      onlyOutOfStock: _filterOutOfStock,
      onlyInactive: _filterHidden,
      onlyActive: _filterActiveOnly,
      photoFilter: _photoFilter,
    );
    if (!mounted || requestId != _inventoryRequestId) {
      return List<PartModel>.unmodifiable(_loadedParts);
    }
    if (batch.length < ImporterInventoryLayout.pageSize) {
      _hasMoreInventory = false;
    }
    if (reset) {
      _loadedParts
        ..clear()
        ..addAll(batch);
    } else {
      _loadedParts.addAll(batch);
    }
    if (preserveScroll) _restoreInventoryOffset();
    return List<PartModel>.unmodifiable(_loadedParts);
  }

  List<PartModel> get _pageParts => sliceListPage(
        items: _loadedParts,
        pageIndex: _productPageIndex,
        pageSize: _productPageSize,
      );

  Future<void> _openProductPage(int index) async {
    final needed = (index + 1) * _productPageSize;
    while (mounted && _hasMoreInventory && _loadedParts.length < needed) {
      final before = _loadedParts.length;
      await _loadMoreInventory();
      if (_loadedParts.length == before) break;
    }
    if (!mounted) return;
    setState(() {
      _productPageIndex = clampListPageIndex(
        pageIndex: index,
        total: _loadedParts.length,
        pageSize: _productPageSize,
      );
    });
  }

  Future<void> _loadMoreInventory() async {
    if (_loadingMoreInventory || !_hasMoreInventory) return;
    setState(() => _loadingMoreInventory = true);
    try {
      await _fetchInventoryPage(reset: false);
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar más productos.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingMoreInventory = false);
      } else {
        _loadingMoreInventory = false;
      }
    }
  }

  Future<void> _pullToRefresh() async {
    _reload();
    final pending = _partsFuture;
    if (pending != null) await pending;
  }

  double _listBottomPaddingFor(double width) =>
      ImporterInventoryLayout.listBottomPadding(
        width: width,
        bulkMode: _inSelectionMode,
        deleteOnly: _selectionMode == _InventorySelectionMode.delete,
      );

  String _productDeleteLabel(PartModel part) {
    final name = part.nombre.trim();
    if (name.isNotEmpty) return name;
    final sku = part.sku?.trim();
    if (sku != null && sku.isNotEmpty) return sku;
    return 'Producto';
  }

  Future<bool> _confirmDeleteDialog({
    required List<PartModel> products,
  }) async {
    if (products.isEmpty) return false;
    final count = products.length;
    final scrollable = count > 3;
    final result = await showAdaptiveAdminSheet<bool>(
      context: context,
      draggable: scrollable,
      initialChildSize: count > 8 ? 0.82 : 0.68,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (ctx, scroll) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        final list = ListView.separated(
          controller: scroll,
          shrinkWrap: !scrollable,
          physics: scrollable ? null : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final part = products[index];
            final sku = part.sku?.trim();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _productThumbnail(part, desktop: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _productDeleteLabel(part),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                      if (sku != null && sku.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'SKU $sku',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12 + bottom),
          child: Column(
            mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                count == 1 ? 'Eliminar producto' : 'Eliminar $count productos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Se quitan del inventario y del catálogo. No se puede deshacer.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (scrollable) Expanded(child: list) else list,
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(count == 1 ? 'Eliminar' : 'Eliminar $count'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }

  List<PartModel> _partsByIds(Iterable<String> ids) {
    final byId = {for (final part in _loadedParts) part.id: part};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> _applyDeleteResult(ProductDeleteBatchResult result) async {
    if (!mounted) return;
    if (result.hasDeleted) {
      setState(() {
        _selectedIds.removeWhere(result.deletedIds.contains);
        if (_selectedIds.isEmpty) {
          _selectionMode = _InventorySelectionMode.none;
        }
      });
      _reload();
    }

    if (result.hasBlocked) {
      final action = await showProductDeleteOutcomeSheet(
        context: context,
        result: result,
      );
      if (!mounted) return;
      if (action == ProductDeleteOutcomeAction.pauseBlocked) {
        await _pauseBlockedProducts(result.blockedIds);
      }
      return;
    }

    if (result.hasDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.deletedCount == 1
                ? 'Producto eliminado.'
                : '${result.deletedCount} productos eliminados.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pauseBlockedProducts(List<String> ids) async {
    final targets = ids.where((id) => id.isNotEmpty).toList();
    if (targets.isEmpty) return;
    try {
      await SupabaseService.setProductsActiveBulk(
        productIds: targets,
        isActive: false,
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targets.length == 1
                ? 'Producto pausado. Ya no aparece en el catálogo.'
                : '${targets.length} productos pausados. Ya no aparecen en el catálogo.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo pausar: $e')),
      );
    }
  }

  Future<void> _deleteSingle(PartModel part) async {
    final ok = await _confirmDeleteDialog(products: [part]);
    if (!ok || !mounted) return;
    try {
      final result = await SupabaseService.deleteProduct(
        productId: part.id,
        label: _productDeleteLabel(part),
      );
      if (!mounted) return;
      await _applyDeleteResult(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  Future<void> _deleteSelectedBulk() async {
    if (_selectedIds.isEmpty) return;
    final products = _partsByIds(_selectedIds);
    if (products.isEmpty) return;
    final ok = await _confirmDeleteDialog(products: products);
    if (!ok || !mounted) return;
    final ids = products.map((part) => part.id).toList();
    final labels = {
      for (final part in products) part.id: _productDeleteLabel(part),
    };
    try {
      final result = await SupabaseService.deleteProductsBulk(
        productIds: ids,
        labelsById: labels,
      );
      if (!mounted) return;
      await _applyDeleteResult(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  Future<void> _startBulkPhotos() async {
    final result = await ImporterBulkPhotosScreen.open(context);
    if (!mounted || result == null) return;
    if (result.updated > 0) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Fotos: ${result.updated} producto(s) actualizado(s).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportRegisteredInventory() async {
    try {
      final parts = await SupabaseService.fetchMyInventory(limit: 2000);
      if (parts.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes productos registrados para exportar.'),
          ),
        );
        return;
      }
      final bytes = ExcelCatalogService.buildInventoryExportBytes(parts);
      final result = await saveExcelForExport(
        name: 'b2bconecta_inventario',
        bytes: bytes,
      );
      if (!mounted) return;
      if (result == ExcelExportResult.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exportación de inventario cancelada.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            excelExportSavedMessage(
              'Inventario exportado (${parts.length} producto(s)).',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar el inventario: $e')),
      );
    }
  }

  Future<void> _showHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Carga masiva, en 4 pasos',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                'Sube tu listado, revisa las columnas y publica. '
                'Las tiendas verán el catálogo al instante.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _helpGuideStep(
                      step: '1',
                      icon: Icons.upload_file_outlined,
                      title: 'Elige tu archivo',
                      body:
                          'Sube el Excel o CSV de tu ERP (Profit, Saint, etc.) '
                          'o descarga la plantilla lista para llenar.',
                    ),
                    _helpGuideStep(
                      step: '2',
                      icon: Icons.view_column_outlined,
                      title: 'Confirma las columnas',
                      body: 'B2B Conecta propone SKU, nombre, precio y stock. '
                          'Revisa el mapeo; el resto puede quedar como dato interno.',
                    ),
                    _helpGuideStep(
                      step: '3',
                      icon: Icons.storefront_outlined,
                      title: 'Importa y decide la visibilidad',
                      body:
                          'Puedes elegir pausados o visibles para códigos nuevos, '
                          'o fijarlo fila a fila con la columna activo (si/no). '
                          'Vacío en un SKU existente no cambia su visibilidad.',
                    ),
                    _helpGuideStep(
                      step: '4',
                      icon: Icons.photo_library_outlined,
                      title: 'Añade fotos (opcional)',
                      body: 'ZIP con el nombre del SKU de cada producto: '
                          'ACE-4.jpg, ACE-4_2.jpg, ACE-4_3.jpg (máx. 3). '
                          'En variantes, usa el SKU de cada opción.',
                      isLast: true,
                    ),
                    _helpCallout(
                      icon: Icons.layers_outlined,
                      title: 'Varias presentaciones, una ficha',
                      body:
                          'Mismo parent_sku en varias filas. Un eje: atributo + '
                          'valor_atributo. Varios ejes (talla y color): columna '
                          'atributos, ej. Tamaño:M|Color:Rojo. Cada combinación '
                          'es un SKU; en la vitrina sale una tarjeta con selectores.',
                    ),
                    const SizedBox(height: 10),
                    _helpCallout(
                      icon: Icons.download_outlined,
                      title: 'Edita lo que ya tienes',
                      body:
                          '«Exportar inventario» descarga b2bconecta_inventario.xlsx '
                          'con cantidad_minima, variantes e imagen. Edítalo y '
                          'vuelve a cargarlo.',
                    ),
                    const SizedBox(height: 10),
                    _helpCallout(
                      icon: Icons.tune_outlined,
                      title: 'Pedido mínimo a tu medida',
                      body: 'Si dejas cantidad_minima vacía, queda en 5. '
                          'Si pones 1, 2 u otro valor, esa cantidad manda.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  }

  Widget _helpGuideStep({
    required String step,
    required IconData icon,
    required String title,
    required String body,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 14 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20, color: AppColors.brandBlue),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.brandBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      step,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpCallout({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer.withOpacity(0.35),
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.brandBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadImportTemplate() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Plantilla de ejemplo',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Excel (.xlsx)'),
              subtitle: const Text(
                'Incluye mínimo, variantes e imagen',
              ),
              onTap: () => Navigator.pop(ctx, 'xlsx'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('CSV (.csv)'),
              subtitle: const Text(
                'Mismo layout, separado por coma',
              ),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    try {
      if (choice == 'csv') {
        final result = await saveCsvForExport(
          name: 'b2bconecta_plantilla_inventario',
          bytes: ExcelCatalogService.buildCsvTemplateBytes(),
        );
        if (!mounted) return;
        if (result == ExcelExportResult.cancelled) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              excelExportSavedMessage('Plantilla CSV descargada.'),
            ),
          ),
        );
        return;
      }
      final result = await saveExcelForExport(
        name: 'b2bconecta_plantilla_inventario',
        bytes: ExcelCatalogService.buildTemplateBytes(),
      );
      if (!mounted) return;
      if (result == ExcelExportResult.cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            excelExportSavedMessage('Plantilla Excel descargada.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar la plantilla: $e')),
      );
    }
  }

  Future<void> _startBulkImport() async {
    final picked = await pickSpreadsheetFile();
    if (picked == null) return;
    final bytes = picked.bytes;
    if (bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron leer los datos del archivo. Prueba otra vez.',
          ),
        ),
      );
      return;
    }

    final name = picked.fileName;
    final isCsv = name.toLowerCase().endsWith('.csv');
    final fileMeta = CatalogImportFileMeta(
      name: name,
      format:
          isCsv ? CatalogImportFileFormat.csv : CatalogImportFileFormat.xlsx,
    );

    CatalogImportPreview preview;
    try {
      preview = CatalogImportOrchestrator.preview(
        bytes: bytes,
        fileMeta: fileMeta,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo leer el archivo: $e')),
      );
      return;
    }

    if (preview.headers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo no tiene cabeceras.')),
      );
      return;
    }

    if (!mounted) return;

    final importResult = await ImporterFlexibleImportScreen.open(
      context,
      fileName: name,
      bytes: bytes,
      fileMeta: fileMeta,
      preview: preview,
      pagoSoloDivisas: _pagoSoloDivisas,
    );

    if (!mounted || importResult == null) return;
    if (!importResult.dryRun && importResult.successCount > 0) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Carga masiva: ${importResult.inserted} nuevo(s), '
            '${importResult.updated} actualizado(s).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEditor(PartModel? part) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ImporterProductEditScreen(initial: part),
      ),
    );
    if (saved == true) _reload();
  }

  void _setSelectionMode(_InventorySelectionMode mode) {
    setState(() {
      if (_selectionMode != mode) _selectedIds.clear();
      _selectionMode = mode;
      if (mode == _InventorySelectionMode.none) _selectedIds.clear();
    });
  }

  Future<void> _toggleSelectAllProducts() async {
    while (mounted && _hasMoreInventory) {
      final before = _loadedParts.length;
      await _loadMoreInventory();
      if (!mounted || _loadedParts.length == before) break;
    }
    if (!mounted || _loadedParts.isEmpty) return;
    setState(() {
      final ids = _loadedParts.map((part) => part.id);
      final allSelected =
          _loadedParts.every((part) => _selectedIds.contains(part.id));
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  void _toggleRowSelected(PartModel p) {
    setState(() {
      if (_selectedIds.contains(p.id)) {
        _selectedIds.remove(p.id);
      } else {
        _selectedIds.add(p.id);
      }
    });
  }

  void _patchLoadedPartActive(String id, bool isActive) {
    final i = _loadedParts.indexWhere((part) => part.id == id);
    if (i < 0) return;
    _loadedParts[i] = _loadedParts[i].copyWith(isActive: isActive);
  }

  /// Si el filtro activo ya no admite el producto, lo saca de la lista local
  /// sin reiniciar página ni scroll.
  void _dropLoadedPartIfFilteredOut(String id, bool isActive) {
    final excludedByFilter =
        (_filterActiveOnly && !isActive) || (_filterHidden && isActive);
    if (!excludedByFilter) return;
    _loadedParts.removeWhere((part) => part.id == id);
    _selectedIds.remove(id);
    _productPageIndex = clampListPageIndex(
      pageIndex: _productPageIndex,
      total: _loadedParts.length,
      pageSize: _productPageSize,
    );
  }

  void _refreshInventoryMetricsQuietly() {
    _metricsFuture = SupabaseService.fetchMyInventoryMetrics();
  }

  Future<void> _applyBulkVisibility({required bool isActive}) async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    final previousById = <String, bool>{
      for (final part in _loadedParts)
        if (ids.contains(part.id)) part.id: part.isActive,
    };

    setState(() {
      for (final id in ids) {
        _patchLoadedPartActive(id, isActive);
      }
      _selectedIds.clear();
      _selectionMode = _InventorySelectionMode.none;
    });

    try {
      await SupabaseService.setProductsActiveBulk(
        productIds: ids,
        isActive: isActive,
      );
      if (!mounted) return;
      setState(() {
        for (final id in ids) {
          _dropLoadedPartIfFilteredOut(id, isActive);
        }
        _refreshInventoryMetricsQuietly();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? 'Visibilidad activada en ${ids.length} productos.'
                : '${ids.length} productos pausados. Ya no se ven en las tiendas.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (final entry in previousById.entries) {
          _patchLoadedPartActive(entry.key, entry.value);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  Future<void> _toggleActive(PartModel part, bool value) async {
    if (part.isActive == value) return;
    final previous = part.isActive;

    setState(() {
      _togglingProductIds.add(part.id);
      _patchLoadedPartActive(part.id, value);
    });

    try {
      await SupabaseService.setProductActive(
        productId: part.id,
        isActive: value,
      );
      if (!mounted) return;
      setState(() {
        _dropLoadedPartIfFilteredOut(part.id, value);
        _refreshInventoryMetricsQuietly();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _patchLoadedPartActive(part.id, previous);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingProductIds.remove(part.id));
      }
    }
  }

  Widget _productThumbnail(PartModel p, {required bool desktop}) {
    final size = desktop ? 72.0 : 56.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty
            ? Image.network(
                p.coverImageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _thumbPlaceholder(size),
              )
            : _thumbPlaceholder(size),
      ),
    );
  }

  Widget _thumbPlaceholder(double size) {
    return ColoredBox(
      color: AppColors.fieldFill,
      child: Icon(
        Icons.precision_manufacturing_outlined,
        size: size * 0.42,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _buildProductTile(PartModel p, {required bool desktop}) {
    return InventoryProductTile(
        part: p,
        soloDivisas: _pagoSoloDivisas,
        selecting: _inSelectionMode,
        selected: _selectedIds.contains(p.id),
        onSelect: () => _toggleRowSelected(p),
        onEdit: () => _openEditor(p),
        onShare: () => showProductShareSheet(context, p),
        onDelete: () => _deleteSingle(p),
        onVisibilityChanged: _togglingProductIds.contains(p.id)
            ? null
            : (v) => _toggleActive(p, v));
  }

  void _shareStoreQr() {
    final id = SupabaseService.currentUserId;
    if (id == null || id.isEmpty) return;
    final name = _priorityProfile?.businessName?.trim();
    showShareQrSheet(
      context,
      title: (name == null || name.isEmpty) ? 'Mi vitrina' : name,
      url: ImporterStoreShareLink.urlFor(id),
      subtitle: 'Vitrina del proveedor',
    );
  }

  void _onInventoryRequest() {
    if (!mounted) return;
    final request = MainShellTabController.importerInventoryRequest.value;
    if (request == null) return;
    MainShellTabController.importerInventoryRequest.value = null;
    if (request == 'agregar') {
      _openEditor(null);
      return;
    }
    setState(() {
      _searchController.clear();
      _categoryFilter = 'Todas';
      _photoFilter = ProductPhotoListFilter.all;
      _filterLowStock = false;
      _filterActiveOnly = false;
      _filterHidden = request == 'pausados';
      _filterOutOfStock = request == 'sin_stock';
    });
    _reloadInventory(refreshMetrics: false);
  }

  int get _quickView => _filterOutOfStock
      ? 3
      : _filterHidden
          ? 2
          : _filterActiveOnly
              ? 1
              : 0;

  void _selectQuickView(int index) {
    setState(() {
      _filterActiveOnly = index == 1;
      _filterHidden = index == 2;
      _filterOutOfStock = index == 3;
    });
    _reloadInventory(refreshMetrics: false);
  }

  void _resetFilters() {
    setState(() {
      _categoryFilter = 'Todas';
      _photoFilter = ProductPhotoListFilter.all;
      _filterLowStock =
          _filterOutOfStock = _filterHidden = _filterActiveOnly = false;
      _searchController.clear();
    });
    _reloadInventory(refreshMetrics: false);
  }

  int get _advancedFilterCount =>
      (_categoryFilter != 'Todas' ? 1 : 0) +
      (_photoFilter != ProductPhotoListFilter.all ? 1 : 0) +
      (_filterLowStock ? 1 : 0);

  Future<void> _openFilters() async {
    InventoryMetrics? metrics;
    try {
      metrics = await _metricsFuture;
    } catch (_) {/* La hoja sigue siendo usable. */}
    if (!mounted) return;
    final categories =
        <String>{'Todas', ...?metrics?.categories, _categoryFilter}.toList();
    var category = _categoryFilter;
    var photo = _photoFilter;
    var lowStock = _filterLowStock;
    final applied = await showAdaptiveAdminSheet<bool>(
      context: context,
      draggable: true,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (ctx, scroll) => StatefulBuilder(
          builder: (ctx, update) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Filtrar productos',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800))),
                      IconButton(
                          tooltip: 'Cerrar filtros',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ]),
                    Expanded(
                        child: ListView(controller: scroll, children: [
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          value: category,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Categoría'),
                          items: categories
                              .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) update(() => category = value);
                          }),
                      if (metrics == null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                                'No se pudieron cargar todas las categorías. Actualiza el inventario para reintentar.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12))),
                      const SizedBox(height: 24),
                      const Text('Fotos',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        for (final option in ProductPhotoListFilter.values)
                          ChoiceChip(
                              label: Text(switch (option) {
                                ProductPhotoListFilter.all => 'Todas',
                                ProductPhotoListFilter.withPhotos =>
                                  'Con fotos',
                                ProductPhotoListFilter.withoutPhotos =>
                                  'Sin fotos',
                              }),
                              selected: photo == option,
                              onSelected: (_) => update(() => photo = option)),
                      ]),
                      const SizedBox(height: 16),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('No alcanza la compra mínima'),
                          subtitle: const Text(
                              'El stock disponible no cubre el mínimo de unidades del producto.'),
                          value: lowStock,
                          onChanged: (value) => update(() => lowStock = value)),
                    ])),
                    const SizedBox(height: 12),
                    Row(children: [
                      TextButton(
                          onPressed: () => update(() {
                                category = 'Todas';
                                photo = ProductPhotoListFilter.all;
                                lowStock = false;
                              }),
                          child: const Text('Restablecer')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Aplicar filtros'))),
                    ]),
                  ]))),
    );
    if (applied != true || !mounted) return;
    setState(() {
      _categoryFilter = category;
      _photoFilter = photo;
      _filterLowStock = lowStock;
    });
    _reloadInventory(refreshMetrics: false);
  }

  Widget _toolsMenu({required bool compact}) => PopupMenuButton<String>(
        icon: compact ? const Icon(Icons.more_horiz) : null,
        tooltip: 'Herramientas de inventario',
        onSelected: (action) {
          switch (action) {
            case 'import':
              _startBulkImport();
            case 'photos':
              _startBulkPhotos();
            case 'template':
              _downloadImportTemplate();
            case 'export':
              _exportRegisteredInventory();
            case 'share':
              _shareStoreQr();
            case 'select':
              _setSelectionMode(_InventorySelectionMode.visibility);
            case 'delete':
              _setSelectionMode(_InventorySelectionMode.delete);
            case 'help':
              _showHelpDialog();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'import', child: Text('Importar Excel / CSV')),
          PopupMenuItem(value: 'photos', child: Text('Importar ZIP de fotos')),
          PopupMenuItem(value: 'template', child: Text('Descargar plantilla')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'export', child: Text('Exportar a Excel')),
          PopupMenuItem(value: 'share', child: Text('Compartir vitrina / QR')),
          PopupMenuDivider(),
          PopupMenuItem(
              value: 'select', child: Text('Publicar o pausar varios')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar varios')),
          PopupMenuItem(value: 'help', child: Text('Ayuda de importación')),
        ],
        child: compact
            ? null
            : const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.more_horiz, size: 20),
                  SizedBox(width: 6),
                  Text('Herramientas'),
                ])),
      );

  Widget _inventoryBrowseLayout({
    required bool isDesktop,
    required double hPad,
    required Widget content,
  }) {
    return CatalogBrowseLayout(
      heading: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: FutureBuilder<InventoryMetrics>(
                      future: _metricsFuture,
                      builder: (context, snapshot) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isDesktop)
                                  const Text('Inventario',
                                      style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800)),
                                Text(
                                    snapshot.hasData
                                        ? '${snapshot.data!.totalProducts} productos registrados'
                                        : 'Tus productos',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ]))),
              IconButton(
                  tooltip: 'Actualizar inventario',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh, size: 21)),
              const SizedBox(width: 4),
              FilledButton.icon(
                  onPressed: _inSelectionMode ? null : () => _openEditor(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(44, 44))),
            ]),
            const SizedBox(height: 10),
          ],
        ),
      ),
      search: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) =>
                          _reloadInventory(refreshMetrics: false),
                      decoration: InputDecoration(
                          hintText: 'Buscar nombre o SKU…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: AppColors.fieldFill,
                          suffixIcon: _searchController.text.isEmpty
                              ? IconButton(
                                  tooltip: 'Buscar productos',
                                  onPressed: () =>
                                      _reloadInventory(refreshMetrics: false),
                                  icon:
                                      const Icon(Icons.arrow_forward, size: 20))
                              : IconButton(
                                  tooltip: 'Borrar búsqueda',
                                  onPressed: () {
                                    _searchController.clear();
                                    _reloadInventory(refreshMetrics: false);
                                  },
                                  icon: const Icon(Icons.close, size: 20)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none)))),
              const SizedBox(width: 8),
              IconButton.outlined(
                  tooltip: 'Filtrar productos',
                  onPressed: _openFilters,
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: Badge(
                      isLabelVisible: _advancedFilterCount > 0,
                      label: Text('$_advancedFilterCount'),
                      child: const Icon(Icons.tune, size: 20))),
            ]),
            const SizedBox(height: 6),
          ],
        ),
      ),
      quickFilters: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_inSelectionMode)
              Row(children: [
                const Expanded(
                    child: Text('Selecciona los productos',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                TextButton(
                    onPressed: () =>
                        _setSelectionMode(_InventorySelectionMode.none),
                    child: const Text('Cancelar')),
              ])
            else
              Row(children: [
                Expanded(
                    child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final (index, label) in const [
                            'Todos',
                            'Publicados',
                            'Pausados',
                            'Sin stock'
                          ].indexed)
                            Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                    showCheckmark: false,
                                    label: Text(label),
                                    selected: _quickView == index,
                                    onSelected: (_) =>
                                        _selectQuickView(index))),
                        ]))),
                _toolsMenu(compact: !isDesktop),
              ]),
            if (_advancedFilterCount > 0)
              Row(children: [
                Expanded(
                    child: Text(
                        [
                          if (_categoryFilter != 'Todas') _categoryFilter,
                          if (_photoFilter == ProductPhotoListFilter.withPhotos)
                            'Con fotos',
                          if (_photoFilter ==
                              ProductPhotoListFilter.withoutPhotos)
                            'Sin fotos',
                          if (_filterLowStock) 'No alcanza el mínimo',
                        ].join(' · '),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary))),
                TextButton(
                    onPressed: _resetFilters, child: const Text('Restablecer')),
              ]),
          ],
        ),
      ),
      content: content,
    );
  }

  List<Widget> _inventoryBodySlivers(
    AsyncSnapshot<List<PartModel>> snapshot, {
    required bool isDesktop,
    required double hPad,
    required double listBottomPadding,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        _loadedParts.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          ),
        ),
      ];
    }
    if (snapshot.hasError && _loadedParts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('No se pudieron cargar los productos.'),
              TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar')),
            ]),
          ),
        ),
      ];
    }

    final parts = _pageParts;

    if (parts.isEmpty) {
      final hasFilters = _filterOutOfStock ||
          _filterLowStock ||
          _filterHidden ||
          _filterActiveOnly ||
          _photoFilter != ProductPhotoListFilter.all ||
          _categoryFilter != 'Todas' ||
          _searchController.text.trim().isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad + 8),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasFilters
                        ? 'Sin resultados con los filtros actuales.'
                        : 'Tu inventario está vacío',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasFilters
                        ? 'Prueba quitar filtros o actualizar la lista.'
                        : 'Sube el Excel de tu ERP o añade productos uno a uno.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  if (hasFilters)
                    TextButton(
                        onPressed: _resetFilters,
                        child: const Text('Restablecer filtros')),
                  if (!hasFilters) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _startBulkImport,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Importar productos'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
        sliver: SliverList.separated(
          itemCount: parts.length,
          separatorBuilder: (_, __) => SizedBox(height: isDesktop ? 10 : 8),
          itemBuilder: (context, i) =>
              _buildProductTile(parts[i], desktop: isDesktop),
        ),
      ),
      if (_loadingMoreInventory)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
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
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, listBottomPadding),
          child: ListPageBar(
            bottomPadding: 0,
            total: _loadedParts.length,
            hasMore: _hasMoreInventory,
            pageIndex: _productPageIndex,
            pageSize: _productPageSize,
            onPageIndex: _openProductPage,
            onPageSize: (size) {
              setState(() {
                _productPageSize = size;
                _productPageIndex = 0;
              });
              if (_inventoryScrollController.hasClients) {
                _inventoryScrollController.jumpTo(0);
              }
            },
          ),
        ),
      ),
    ];
  }

  Widget _buildSelectionBottomBar({required bool isDesktop}) {
    final allSelected = _loadedParts.isNotEmpty &&
        !_hasMoreInventory &&
        _loadedParts.every((p) => _selectedIds.contains(p.id));
    final isDelete = _selectionMode == _InventorySelectionMode.delete;
    final hint = isDelete
        ? 'Marca los productos que quieres eliminar.'
        : 'Toca filas o casillas para cambiar visibilidad.';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        elevation: 12,
        color: AppColors.surfaceTinted,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 12,
              10,
              isDesktop ? 24 : 12,
              12,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop
                    ? AppBreakpoints.productDetailMaxWidth
                    : double.infinity,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedIds.isEmpty
                              ? hint
                              : '${_selectedIds.length} seleccionados',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (_loadedParts.isNotEmpty)
                        TextButton(
                          onPressed: _loadingMoreInventory
                              ? null
                              : _toggleSelectAllProducts,
                          child: Text(
                            allSelected ? 'Quitar todo' : 'Seleccionar todo',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isDelete)
                    FilledButton.icon(
                      onPressed:
                          _selectedIds.isEmpty ? null : _deleteSelectedBulk,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(
                        _selectedIds.isEmpty
                            ? 'Eliminar seleccionados'
                            : 'Eliminar ${_selectedIds.length}',
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectedIds.isEmpty
                                ? null
                                : () => _applyBulkVisibility(isActive: true),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: const Text('Activar visibilidad'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _selectedIds.isEmpty
                                ? null
                                : () => _applyBulkVisibility(isActive: false),
                            icon: const Icon(
                              Icons.pause_circle_outline,
                              size: 18,
                            ),
                            label: const Text('Pausar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = ImporterInventoryLayout.isDesktop(width);
        final hPad = ImporterInventoryLayout.horizontalPadding(width);
        final listBottomPadding = _listBottomPaddingFor(width);

        return Stack(
          children: [
            _inventoryBrowseLayout(
              isDesktop: isDesktop,
              hPad: hPad,
              content: FutureBuilder<List<PartModel>>(
                future: _partsFuture,
                builder: (context, snapshot) => RefreshIndicator(
                  onRefresh: _pullToRefresh,
                  color: AppColors.brand,
                  child: CustomScrollView(
                    controller: _inventoryScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: _inventoryBodySlivers(
                      snapshot,
                      isDesktop: isDesktop,
                      hPad: hPad,
                      listBottomPadding: listBottomPadding,
                    ),
                  ),
                ),
              ),
            ),
            if (_inSelectionMode)
              _buildSelectionBottomBar(isDesktop: isDesktop),
          ],
        );
      },
    );
  }
}
