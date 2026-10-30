import 'package:flutter/material.dart';

import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_count_card.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_share_link.dart';
import 'package:motolink_pro_app/features/catalog/product_share_sheet.dart';
import 'package:motolink_pro_app/features/catalog/share_qr_sheet.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'importer_onboarding_checklist.dart';
import 'importer_onboarding_checklist_card.dart';
import 'importer_priority_actions.dart';
import 'importer_product_edit_screen.dart';
import 'catalog_import_orchestrator.dart';
import 'excel_catalog_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'importer_bulk_photos_screen.dart';
import 'importer_flexible_import_screen.dart';
import 'product_custom_fields_section.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/layout/segmented_filter_bar.dart';
import 'package:motolink_pro_app/core/utils/excel_file_export.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'importer_inventory_layout.dart';
import 'package:motolink_pro_app/features/catalog/importer_promo_widgets.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'importer_sales_snapshot.dart';
import 'product_delete_outcome_sheet.dart';
import 'product_delete_result.dart';
import 'product_images.dart';

enum _InventorySelectionMode { none, visibility, delete }

/// Categorías alineadas al seed / Excel (orden para el filtro).
const _kInventoryCategories = <String>[
  'Todas',
  'Accesorios',
  'Chasis',
  'Eléctrico',
  'Frenos',
  'Motor',
  'Transmisión',
];

/// Vista "Mi inventario" para importadores: métricas, lista, carga masiva, FAB.
class ImporterInventoryDashboard extends StatefulWidget {
  const ImporterInventoryDashboard({super.key});

  @override
  State<ImporterInventoryDashboard> createState() =>
      _ImporterInventoryDashboardState();
}

class _ImporterInventoryDashboardState extends State<ImporterInventoryDashboard> {
  final _searchController = TextEditingController();
  final _inventoryScrollController = ScrollController();
  Future<InventoryMetrics>? _metricsFuture;
  Future<ImporterSalesSnapshot>? _salesSnapshotFuture;
  int _salesSnapshotDays = 30;
  Future<List<PartModel>>? _partsFuture;
  final List<PartModel> _loadedParts = <PartModel>[];
  int _productPageIndex = 0;
  int _productPageSize = listPageSizeOptions.first;
  bool _hasMoreInventory = true;
  bool _loadingMoreInventory = false;
  String _categoryFilter = 'Todas';
  bool _filterLowStock = false;
  bool _filterHidden = false;
  bool _filterActiveOnly = false;
  ProductPhotoListFilter _photoFilter = ProductPhotoListFilter.all;
  _InventorySelectionMode _selectionMode = _InventorySelectionMode.none;
  bool _pagoSoloDivisas = false;
  ProfileModel? _priorityProfile;
  Future<int?>? _newOrdersCount;
  Future<int?>? _pendingInvoicesCount;
  final Set<String> _selectedIds = <String>{};
  final Set<String> _togglingProductIds = <String>{};

  bool get _inSelectionMode => _selectionMode != _InventorySelectionMode.none;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadImporterPagoPolicy();
    MainShellTabController.registerImporterInventoryReload(_reload);
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
    _searchController.dispose();
    _inventoryScrollController.dispose();
    super.dispose();
  }

  void _reload() => _reloadInventory();

  double? _keptInventoryOffset;

  void _reloadInventory({bool preserveScroll = false}) {
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
      _metricsFuture = SupabaseService.fetchMyInventoryMetrics();
      _newOrdersCount = SupabaseService.countMyNewOrders();
      _pendingInvoicesCount = SupabaseService.countMyPendingCommissionInvoices();
      _salesSnapshotFuture =
          SupabaseService.fetchMySalesSnapshot(days: _salesSnapshotDays);
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
      onlyInactive: _filterHidden,
      onlyActive: _filterActiveOnly,
      photoFilter: _photoFilter,
    );
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
          physics: scrollable
              ? null
              : const NeverScrollableScrollPhysics(),
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
                count == 1
                    ? 'Eliminar producto'
                    : 'Eliminar $count productos',
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

  Widget _inventoryToolbarIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
    Widget? iconWidget,
  }) {
    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.fieldFill,
        foregroundColor: foregroundColor,
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      icon: iconWidget ?? Icon(icon, size: 20),
    );
  }

  List<Widget> _inventoryToolbarButtons() {
    return [
      _inventoryToolbarIcon(
        icon: Icons.qr_code_2,
        tooltip: 'Compartir QR de la vitrina',
        onPressed: _shareStoreQr,
        backgroundColor: AppColors.brandBlue,
        foregroundColor: Colors.white,
      ),
      _inventoryToolbarIcon(
        icon: Icons.help_outline,
        tooltip: 'Cómo funciona la carga masiva',
        onPressed: _showHelpDialog,
      ),
      _inventoryToolbarIcon(
        icon: Icons.download_outlined,
        tooltip: 'Exportar inventario a Excel',
        onPressed: _exportRegisteredInventory,
        backgroundColor: AppColors.brandBlue,
        foregroundColor: Colors.white,
      ),
    ];
  }

  Widget _bulkActionsPanel({required bool isDesktop}) {
    final cards = [
      _bulkCatalogCard(isDesktop: isDesktop),
      _bulkPhotosCard(isDesktop: isDesktop),
    ];
    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cards[0],
          const SizedBox(height: 10),
          cards[1],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 12),
        Expanded(child: cards[1]),
      ],
    );
  }

  Widget _bulkCatalogCard({required bool isDesktop}) {
    return Material(
      color: AppColors.successGreen.withOpacity(0.08),
      borderRadius: AppDecorations.radius12,
      child: InkWell(
        borderRadius: AppDecorations.radius12,
        onTap: _startBulkImport,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isDesktop ? 16 : 14),
          decoration: BoxDecoration(
            borderRadius: AppDecorations.radius12,
            border: Border.all(color: AppColors.successGreen.withOpacity(0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.upload_file, color: AppColors.successGreen.withOpacity(0.9)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Catálogo',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Excel o CSV del ERP → productos, precios y stock.',
                style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _startBulkImport,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  minimumSize: const Size(0, 40),
                ),
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('Elegir Excel / CSV'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _downloadImportTemplate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Descargar plantilla'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bulkPhotosCard({required bool isDesktop}) {
    return Material(
      color: AppColors.brandBlue.withOpacity(0.06),
      borderRadius: AppDecorations.radius12,
      child: InkWell(
        borderRadius: AppDecorations.radius12,
        onTap: _startBulkPhotos,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isDesktop ? 16 : 14),
          decoration: BoxDecoration(
            borderRadius: AppDecorations.radius12,
            border: Border.all(color: AppColors.brandBlue.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.photo_library_outlined, color: AppColors.brandBlue.withOpacity(0.9)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Fotos',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'ZIP con fotos nombradas por SKU (hasta 3 por producto).',
                style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _startBulkPhotos,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  minimumSize: const Size(0, 40),
                ),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Elegir ZIP de fotos'),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _bulkImportBanner({required bool isDesktop}) {
    return _bulkActionsPanel(isDesktop: isDesktop);
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
                      body:
                          'B2B Conecta propone SKU, nombre, precio y stock. '
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
                      body:
                          'ZIP con el nombre del SKU de cada producto: '
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
                      body:
                          'Si dejas cantidad_minima vacía, queda en 5. '
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
      format: isCsv
          ? CatalogImportFileFormat.csv
          : CatalogImportFileFormat.xlsx,
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

  String? _commercialTermsLine(PartModel p) {
    final parts = <String>[];
    if (p.tieneOfertaDirecta) parts.add('Promoción USD');
    parts.add(p.minOrderQtyLabelEs);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
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

  void _enterDeleteSelection({PartModel? initial}) {
    setState(() {
      _selectionMode = _InventorySelectionMode.delete;
      _selectedIds.clear();
      if (initial != null) _selectedIds.add(initial.id);
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

  Widget _visibilitySwitch(PartModel p) {
    final busy = _togglingProductIds.contains(p.id);
    return Tooltip(
      message: p.isActive
          ? 'Publicado. Las tiendas lo ven. Pausa para ocultarlo de inmediato.'
          : 'Pausado. No aparece en el catálogo de las tiendas.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.isActive ? 'Publicado' : 'Pausado',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: p.isActive
                  ? AppColors.successGreen
                  : AppColors.brandAccent,
            ),
          ),
          const SizedBox(height: 2),
          SwitchTheme(
            data: SwitchThemeData(
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.borderSubtle;
                }
                return AppColors.brand.withOpacity(0.85);
              }),
              trackOutlineWidth: WidgetStateProperty.all(1.8),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return Colors.grey.shade400;
                }
                if (states.contains(WidgetState.selected)) {
                  return AppColors.brand;
                }
                return Colors.white;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.brand.withOpacity(0.22);
                }
                return Colors.transparent;
              }),
            ),
            child: Switch(
              value: p.isActive,
              onChanged: busy ? null : (v) => _toggleActive(p, v),
            ),
          ),
        ],
      ),
    );
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
                fit: BoxFit.cover,
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

  Widget _buildProductInfoColumn(PartModel p) {
    final lowStock = !p.stockCoversMinOrder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.nombre,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SKU: ${p.sku ?? p.id}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${p.precio.toStringAsFixed(2)} '
              '${_pagoSoloDivisas ? 'USD' : 'REF'}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lowStock) ...[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  '${p.stock} u.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: lowStock
                        ? Colors.red.shade800
                        : AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_commercialTermsLine(p) != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _commercialTermsLine(p)!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (p.category != null && p.category!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              p.category!,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.brandAccent,
              ),
            ),
          ),
        ProductCustomFieldsChips(customFields: p.customFields),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _photoStatusChip(p.hasPhotos),
              if (!p.hasPhotos && !_inSelectionMode)
                TextButton(
                  onPressed: () => _openEditor(p),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.brand,
                  ),
                  child: const Text('Agregar fotos'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoStatusChip(bool hasPhotos) {
    final color = hasPhotos ? AppColors.successGreen : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        hasPhotos ? 'Con fotos' : 'Sin fotos',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _inventoryFilterSummary() {
    final parts = <String>[];
    if (_categoryFilter != 'Todas') parts.add(_categoryFilter);
    switch (_photoFilter) {
      case ProductPhotoListFilter.withPhotos:
        parts.add('Con fotos');
      case ProductPhotoListFilter.withoutPhotos:
        parts.add('Sin fotos');
      case ProductPhotoListFilter.all:
        break;
    }
    if (_filterLowStock) parts.add('Stock bajo');
    if (_filterActiveOnly) parts.add('Publicados');
    if (_filterHidden) parts.add('Pausados');
    if (parts.isEmpty) return 'Categoría, fotos y vista';
    return parts.join(' · ');
  }

  String _photoFilterLabel(
    ProductPhotoListFilter filter,
    InventoryMetrics? metrics,
  ) {
    switch (filter) {
      case ProductPhotoListFilter.all:
        return 'Todos';
      case ProductPhotoListFilter.withPhotos:
        if (metrics == null) return 'Con fotos';
        return 'Con fotos (${metrics.withPhotos})';
      case ProductPhotoListFilter.withoutPhotos:
        if (metrics == null) return 'Sin fotos';
        return 'Sin fotos (${metrics.withoutPhotos})';
    }
  }

  Widget _buildProductTile(PartModel p, {required bool desktop}) {
    return Material(
      color: AppColors.card,
      borderRadius: AppDecorations.radius12,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppDecorations.radius12,
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: desktop ? AppDecorations.cardShadow : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 12 : 4,
            vertical: desktop ? 10 : 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_inSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Checkbox(
                    value: _selectedIds.contains(p.id),
                    onChanged: (_) => _toggleRowSelected(p),
                    fillColor: WidgetStateProperty.resolveWith((s) {
                      if (s.contains(WidgetState.selected)) {
                        return AppColors.brand;
                      }
                      return null;
                    }),
                  ),
                ),
              if (desktop) ...[
                _productThumbnail(p, desktop: true),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppDecorations.radius12,
                    onTap: _inSelectionMode
                        ? () => _toggleRowSelected(p)
                        : () => _openEditor(p),
                    onLongPress: _inSelectionMode
                        ? null
                        : () => _enterDeleteSelection(initial: p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!desktop) ...[
                            _productThumbnail(p, desktop: false),
                            const SizedBox(width: 10),
                          ],
                          Expanded(child: _buildProductInfoColumn(p)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!_inSelectionMode) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 4, top: 4),
                  child: _visibilitySwitch(p),
                ),
                IconButton(
                  tooltip: 'Compartir producto',
                  onPressed: () => showProductShareSheet(context, p),
                  icon: const Icon(
                    Icons.ios_share_rounded,
                    color: AppColors.brand,
                    size: 22,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Eliminar',
                  onSelected: (value) {
                    if (value == 'one') _deleteSingle(p);
                    if (value == 'many') _enterDeleteSelection(initial: p);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'one',
                      child: Text(
                        'Eliminar este',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'many',
                      child: Text('Elegir varios'),
                    ),
                  ],
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade700,
                    size: 22,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _applyVista(int index) {
    setState(() {
      _filterLowStock = index == 1;
      _filterActiveOnly = index == 2;
      _filterHidden = index == 3;
    });
    _reloadInventory();
  }

  String _countLabel(AsyncSnapshot<int?> snap) {
    if (snap.connectionState != ConnectionState.done) return '…';
    final value = snap.data;
    if (snap.hasError || value == null) return '—';
    return '$value';
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

  static const _inventorySectionGap = 12.0;

  Widget _inventorySection({
    required double hPad,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, _inventorySectionGap, hPad, 0),
      child: child,
    );
  }

  EdgeInsets _inventoryNoticePadding(double hPad) =>
      EdgeInsets.fromLTRB(hPad, _inventorySectionGap, hPad, 0);

  InputDecoration _inventorySearchDecoration() {
    return InputDecoration(
      hintText: 'Buscar por nombre, SKU, categoría…',
      hintStyle: AppColors.hintStyle,
      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
      suffixIcon: IconButton(
        tooltip: 'Buscar',
        onPressed: () => _reloadInventory(preserveScroll: true),
        icon: Icon(Icons.arrow_forward_rounded, color: AppColors.brandBlue),
      ),
      isDense: true,
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppDecorations.radius12,
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppDecorations.radius12,
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
    );
  }

  Widget _inventorySearchField() {
    return TextField(
      controller: _searchController,
      decoration: _inventorySearchDecoration(),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _reloadInventory(preserveScroll: true),
    );
  }

  Widget _buildInventoryHeader({required bool isDesktop, required double hPad}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
              if (!isDesktop)
                _inventorySection(
                  hPad: hPad,
                  child: const ImporterStoreCountCard(
                    extended: true,
                    inline: true,
                  ),
                ),
              FutureBuilder<InventoryMetrics>(
                future: _metricsFuture,
                builder: (context, metricsSnap) {
                  final metrics = metricsSnap.data;
                  final steps = ImporterOnboardingChecklist.evaluate(
                    profile: _priorityProfile,
                    metrics: metrics,
                  );
                  if (steps.isComplete) return const SizedBox.shrink();
                  return _inventorySection(
                    hPad: hPad,
                    child: ImporterOnboardingChecklistCard(
                      checklist: steps,
                      onOpenProfile: MainShellTabController.navigateToProfileKycDocumentation,
                      onAddProduct: () => _openEditor(null),
                    ),
                  );
                },
              ),
              FutureBuilder<int?>(
                future: _newOrdersCount,
                builder: (context, ordersSnap) {
                  return FutureBuilder<int?>(
                    future: _pendingInvoicesCount,
                    builder: (context, invoicesSnap) {
                      return FutureBuilder<InventoryMetrics>(
                        future: _metricsFuture,
                        builder: (context, metricsSnap) {
                          final metrics = metricsSnap.data;
                          return _inventorySection(
                            hPad: hPad,
                            child: ImporterPriorityActions(
                            actions: [
                              ImporterPriorityAction(
                                label: 'Pedidos nuevos',
                                value: _countLabel(ordersSnap),
                                icon: Icons.inbox_outlined,
                                onTap: () =>
                                    MainShellTabController.navigateToImporterPedidosExplore(
                                      'nuevos',
                                    ),
                              ),
                              ImporterPriorityAction(
                                label: 'Facturas pendientes',
                                value: _countLabel(invoicesSnap),
                                icon: Icons.receipt_long_outlined,
                                onTap: MainShellTabController
                                    .navigateToImporterPendingCommissions,
                              ),
                              ImporterPriorityAction(
                                label: 'Stock bajo',
                                value: metrics == null ? '…' : '${metrics.lowStock}',
                                icon: Icons.inventory_outlined,
                                onTap: () => _applyVista(1),
                              ),
                              ImporterPriorityAction(
                                label: 'Pausados',
                                value: metrics == null ? '…' : '${metrics.paused}',
                                icon: Icons.pause_circle_outline,
                                onTap: () => _applyVista(3),
                              ),
                            ],
                          ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            FutureBuilder<ImporterSalesSnapshot>(
                future: _salesSnapshotFuture,
                builder: (context, snap) {
                  final data = snap.data;
                  if (data == null) {
                    return const SizedBox.shrink();
                  }
                  final revenue = data.revenueRef.toStringAsFixed(2);
                  final currency = _pagoSoloDivisas ? 'USD' : 'REF';
                  return _inventorySection(
                    hPad: hPad,
                    child: _InventoryDisclosure(
                      title: 'Desempeño de ventas',
                      subtitle:
                          '${data.ordersEntregados} entregados · $revenue $currency',
                      icon: Icons.auto_graph_rounded,
                      child: ImporterSalesSnapshotCard(
                        snapshot: data,
                        selectedDays: _salesSnapshotDays,
                        onDaysChanged: (days) {
                          setState(() {
                            _salesSnapshotDays = days;
                            _salesSnapshotFuture =
                                SupabaseService.fetchMySalesSnapshot(days: days);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            _inventorySection(
              hPad: hPad,
              child: _InventoryDisclosure(
                title: 'Cargar catálogo y fotos',
                subtitle: 'Excel, CSV o un ZIP de imágenes',
                icon: Icons.upload_file_outlined,
                child: _bulkImportBanner(isDesktop: isDesktop),
              ),
            ),
            ImporterThirdPartyAdsCarousel(
              padding: _inventoryNoticePadding(hPad),
            ),
            ImporterActivePromoBanner(
              padding: _inventoryNoticePadding(hPad),
            ),
            _inventorySection(
              hPad: hPad,
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _inventorySearchField()),
                        const SizedBox(width: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: _inventoryToolbarButtons(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _inventorySearchField(),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.start,
                          children: _inventoryToolbarButtons(),
                        ),
                      ],
                    ),
            ),
            _inventorySection(
              hPad: hPad,
              child: _InventoryDisclosure(
                title: 'Filtros',
                subtitle: _inventoryFilterSummary(),
                icon: Icons.filter_list,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Categoría',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _categoryFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppDecorations.radius12,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    borderRadius: AppDecorations.radius12,
                    items: _kInventoryCategories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _categoryFilter = v);
                      _reloadInventory(preserveScroll: true);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fotos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<InventoryMetrics>(
                    future: _metricsFuture,
                    builder: (context, snap) {
                      final metrics = snap.data;
                      const options = ProductPhotoListFilter.values;
                      return SegmentedFilterBar(
                        labels: [
                          for (final option in options)
                            _photoFilterLabel(option, metrics),
                        ],
                        selectedIndex: options.indexOf(_photoFilter),
                        onSelected: (index) {
                          final option = options[index];
                          if (_photoFilter == option) return;
                          setState(() => _photoFilter = option);
                          _reloadInventory(preserveScroll: true);
                        },
                      );
                    },
                  ),
                  Text(
                    'Vista',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedFilterBar(
                    labels: const [
                      'Todos',
                      'Stock bajo',
                      'Publicados',
                      'Pausados',
                    ],
                    selectedIndex: _filterLowStock
                        ? 1
                        : _filterActiveOnly
                            ? 2
                            : _filterHidden
                                ? 3
                                : 0,
                    onSelected: (index) {
                      setState(() {
                        _filterLowStock = index == 1;
                        _filterActiveOnly = index == 2;
                        _filterHidden = index == 3;
                      });
                      _reloadInventory(preserveScroll: true);
                    },
                  ),
                ],
              ),
              ),
            ),
            _inventorySection(
              hPad: hPad,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandAccent,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _reload(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar lista'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandAccent,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _setSelectionMode(
                      _selectionMode == _InventorySelectionMode.visibility
                          ? _InventorySelectionMode.none
                          : _InventorySelectionMode.visibility,
                    ),
                    icon: Icon(
                      _selectionMode == _InventorySelectionMode.visibility
                          ? Icons.close
                          : Icons.checklist_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _selectionMode == _InventorySelectionMode.visibility
                          ? 'Salir de selección'
                          : 'Gestionar visibilidad',
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _setSelectionMode(
                      _selectionMode == _InventorySelectionMode.delete
                          ? _InventorySelectionMode.none
                          : _InventorySelectionMode.delete,
                    ),
                    icon: Icon(
                      _selectionMode == _InventorySelectionMode.delete
                          ? Icons.close
                          : Icons.delete_outline,
                      size: 18,
                      color: Colors.red.shade700,
                    ),
                    label: Text(
                      _selectionMode == _InventorySelectionMode.delete
                          ? 'Cancelar'
                          : 'Eliminar varios',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
      ],
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
            child: Text(
              'Error: ${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ];
    }

    final parts = _pageParts;

    if (parts.isEmpty) {
      final hasFilters = _filterLowStock ||
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
                  if (!hasFilters) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _startBulkImport,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Carga masiva'),
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
        ? 'Marca los productos. También puedes mantener pulsada una fila.'
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: FutureBuilder<List<PartModel>>(
                    future: _partsFuture,
                    builder: (context, snapshot) {
                      return RefreshIndicator(
                        onRefresh: _pullToRefresh,
                        color: AppColors.brand,
                        child: CustomScrollView(
                            controller: _inventoryScrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: _buildInventoryHeader(
                                  isDesktop: isDesktop,
                                  hPad: hPad,
                                ),
                              ),
                              ..._inventoryBodySlivers(
                                snapshot,
                                isDesktop: isDesktop,
                                hPad: hPad,
                                listBottomPadding: listBottomPadding,
                              ),
                            ],
                          ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_inSelectionMode) _buildSelectionBottomBar(isDesktop: isDesktop),
            Positioned(
              right: isDesktop ? 24 : 16,
              bottom: _inSelectionMode
                  ? (_selectionMode == _InventorySelectionMode.delete
                      ? (isDesktop ? 148 : 128)
                      : (isDesktop ? 200 : 160))
                  : (isDesktop ? 24 : 16),
              child: FloatingActionButton.extended(
                onPressed: _inSelectionMode ? null : () => _openEditor(null),
                backgroundColor: AppColors.brand,
                icon: const Icon(Icons.add),
                label: const Text('Añadir'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InventoryDisclosure extends StatefulWidget {
  const _InventoryDisclosure({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  @override
  State<_InventoryDisclosure> createState() => _InventoryDisclosureState();
}

class _InventoryDisclosureState extends State<_InventoryDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _open ? AppColors.brand : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: AppColors.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}
