import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/part_model.dart';
import '../screens/importer_product_edit_screen.dart';
import '../services/excel_catalog_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_breakpoints.dart';
import '../utils/excel_file_export.dart';
import '../utils/importer_inventory_layout.dart';
import '../utils/product_catalog_pricing.dart';
import '../utils/product_volume_tiers.dart';
import 'importer_bulk_usd_discount_dialog.dart';
import 'importer_promo_widgets.dart';
import 'main_shell_tab.dart';

enum _SkuConflictAction { update, ignore }

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

/// Vista "Mi inventario" para importadores: métricas, lista, carga Excel, FAB.
class ImporterInventoryDashboard extends StatefulWidget {
  const ImporterInventoryDashboard({super.key});

  @override
  State<ImporterInventoryDashboard> createState() =>
      _ImporterInventoryDashboardState();
}

class _ImporterInventoryDashboardState extends State<ImporterInventoryDashboard> {
  final _searchController = TextEditingController();
  Future<InventoryMetrics>? _metricsFuture;
  Future<List<PartModel>>? _partsFuture;
  bool _importing = false;
  String _categoryFilter = 'Todas';
  bool _filterLowStock = false;
  bool _filterHidden = false;
  bool _filterActiveOnly = false;
  _InventorySelectionMode _selectionMode = _InventorySelectionMode.none;
  bool _pagoSoloDivisas = false;
  final Set<String> _selectedIds = <String>{};
  final Set<String> _togglingProductIds = <String>{};
  List<PartModel> _visibleParts = const [];

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
      setState(() => _pagoSoloDivisas = profile?.pagoSoloDivisas ?? false);
    } catch (_) {}
  }

  @override
  void dispose() {
    MainShellTabController.registerImporterInventoryReload(null);
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _metricsFuture = SupabaseService.fetchMyInventoryMetrics();
      _partsFuture = SupabaseService.fetchMyInventory(
        searchQuery: _searchController.text,
        category: _categoryFilter,
        onlyLowStock: _filterLowStock,
        onlyInactive: _filterHidden,
        onlyActive: _filterActiveOnly,
      );
    });
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

  Future<bool> _confirmDeleteDialog({
    required int count,
    String? productName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(count == 1 ? 'Eliminar producto' : 'Eliminar productos'),
        content: Text(
          count == 1
              ? '¿Eliminar «${productName ?? 'este producto'}»? '
                  'Esta acción no se puede deshacer.'
              : '¿Eliminar $count productos seleccionados? '
                  'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(count == 1 ? 'Eliminar' : 'Eliminar $count'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteSingle(PartModel part) async {
    final ok = await _confirmDeleteDialog(count: 1, productName: part.nombre);
    if (!ok || !mounted) return;
    try {
      await SupabaseService.deleteProduct(productId: part.id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto eliminado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  Future<void> _deleteSelectedBulk() async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    final ok = await _confirmDeleteDialog(count: ids.length);
    if (!ok || !mounted) return;
    try {
      await SupabaseService.deleteProductsBulk(productIds: ids);
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _selectionMode = _InventorySelectionMode.none;
      });
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ids.length == 1
                ? '1 producto eliminado.'
                : '${ids.length} productos eliminados.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        icon: Icons.help_outline,
        tooltip: 'Ayuda',
        onPressed: _importing ? null : _showHelpDialog,
      ),
      _inventoryToolbarIcon(
        icon: Icons.table_chart_outlined,
        tooltip: 'Descargar plantilla Excel',
        onPressed: _importing ? null : _downloadTemplate,
        backgroundColor: AppColors.brandBlue,
        foregroundColor: Colors.white,
      ),
      _inventoryToolbarIcon(
        icon: Icons.download_outlined,
        tooltip: 'Exportar inventario actual',
        onPressed: _importing ? null : _exportRegisteredInventory,
        backgroundColor: AppColors.brandOrange,
        foregroundColor: Colors.white,
      ),
      if (!_pagoSoloDivisas)
        _inventoryToolbarIcon(
          icon: Icons.percent_outlined,
          tooltip: 'Actualizar descuentos USD (masivo)',
          onPressed: _importing ? null : _openBulkUsdDiscountDialog,
          backgroundColor: AppColors.brandOrange.withOpacity(0.92),
          foregroundColor: Colors.white,
        ),
      _inventoryToolbarIcon(
        icon: Icons.upload_file,
        tooltip: 'Carga masiva',
        onPressed: _importing ? null : _pickAndImport,
        backgroundColor: AppColors.successGreen,
        foregroundColor: Colors.white,
        iconWidget: _importing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_file, size: 20),
      ),
    ];
  }

  Future<void> _downloadTemplate() async {
    try {
      final bytes = ExcelCatalogService.buildTemplateBytes();
      final result = await saveExcelForExport(
        name: 'motolink_plantilla_inventario',
        bytes: bytes,
      );
      if (!mounted) return;
      if (result == ExcelExportResult.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descarga de plantilla cancelada.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            excelExportSavedMessage('Plantilla lista para descargar.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar la plantilla: $e')),
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
        name: 'motolink_inventario_actual',
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

  Future<_SkuConflictAction?> _askSkuConflict(String sku) async {
    return showDialog<_SkuConflictAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('SKU existente'),
        content: Text(
          'El SKU "$sku" ya está en tu inventario. ¿Qué deseas hacer?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _SkuConflictAction.ignore),
            child: const Text('Ignorar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, _SkuConflictAction.update),
            child: const Text('Actualizar precio y stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Carga masiva de inventario'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '1. Descargar plantilla',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Columnas obligatorias: sku, nombre, precio, stock. '
                'Opcionales: descripcion, precio_oferta_usd, descuento_pago_usd_pct, '
                'categoria, compatibilidad y garantia (si/no). '
                'Los tramos por volumen y la foto se configuran en la app, no en Excel. '
                'La plantilla trae una fila de ejemplo con SKU que empieza por '
                '"EJEMPLO"; no se importa. Puedes borrarla.',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tip: también puedes usar "Exportar inventario actual" para '
                'descargar un Excel con tus productos ya registrados y editarlo.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Importante: los productos nuevos que entren por Excel quedan '
                'ocultos para aliados hasta que actives la visibilidad en la app.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '2. Llenar datos',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'El SKU identifica cada repuesto dentro de tu cuenta. Precio y stock '
                'deben ser números válidos. Sube la imagen y los descuentos por '
                'cantidad al editar el producto en la app.',
              ),
              const SizedBox(height: 16),
              const Text(
                '3. Cargar archivo',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Usa "Carga masiva" para seleccionar el .xlsx. Si un SKU ya existe, '
                'podrás actualizar solo precio y stock o ignorar la fila '
                '(la visibilidad del existente no cambia).',
              ),
              const SizedBox(height: 16),
              const Text(
                '4. Gestionar visibilidad',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Usa el interruptor en cada fila, «Gestionar visibilidad» con la cinta '
                'inferior, «Eliminar varios» o mantén pulsado un producto para borrar '
                'varios a la vez. También puedes usar «Modo pausa» al editar.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
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

    List<ExcelInventoryRow> rows;
    try {
      rows = ExcelCatalogService.parseInventoryBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo inválido: $e')),
      );
      return;
    }

    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay filas de datos en el archivo.')),
      );
      return;
    }

    setState(() => _importing = true);
    var ok = 0;
    var skipped = 0;
    try {
      for (final row in rows) {
        final existingId =
            await SupabaseService.findProductIdByOwnerSku(row.sku);
        if (existingId != null && existingId.isNotEmpty) {
          final action = await _askSkuConflict(row.sku);
          if (action == null || action == _SkuConflictAction.ignore) {
            skipped++;
            continue;
          }
          final existingRules =
              await SupabaseService.fetchProductDiscountRulesById(existingId);
          await SupabaseService.updateProductPriceAndStock(
            productId: existingId,
            priceUsd: row.precio,
            stock: row.stock,
            salePriceUsd: row.precioOfertaUsd,
            discountRules: row.discountRules(
              pagoSoloDivisas: _pagoSoloDivisas,
              preserveVolumeTiersFrom: existingRules,
            ),
            hasWarranty: row.hasWarranty,
          );
          ok++;
        } else {
          try {
            await SupabaseService.insertProduct(
              sku: row.sku,
              name: row.nombre,
              description: row.descripcion,
              priceUsd: row.precio,
              salePriceUsd: row.precioOfertaUsd,
              discountRules: row.discountRules(
                pagoSoloDivisas: _pagoSoloDivisas,
              ),
              stock: row.stock,
              category: row.categoria,
              compatibility: row.compatibilidad,
              imageUrl: row.urlImagen,
              isActive: false,
              hasWarranty: row.hasWarranty,
            );
            ok++;
          } catch (e) {
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Error al insertar'),
                content: Text('SKU ${row.sku}: $e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importación terminada: $ok filas aplicadas. '
            '${skipped > 0 ? '$skipped ignoradas.' : ''}',
          ),
        ),
      );
      _reload();
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openBulkUsdDiscountDialog() async {
    if (_pagoSoloDivisas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Con pagos solo en USD no puede configurar descuentos línea USD. '
            'Use descuentos por volumen u oferta.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _openBulkUsdDiscountDialogImpl();
  }

  String? _commercialTermsLine(PartModel p) {
    final parts = <String>[];
    if (p.tieneOfertaDirecta) parts.add('Oferta');
    final vol = ProductCatalogPricing.volumeIncentiveChipEs(p.discountRules);
    if (vol != null) parts.add(vol);
    if (_pagoSoloDivisas) {
      if (parts.isEmpty) return null;
      return parts.join(' · ');
    }
    final usdPct = parseUsdPaymentDiscountPct(p.discountRules);
    if (usdPct != null) {
      parts.add(
        'USD ${usdPct.toStringAsFixed(usdPct.truncateToDouble() == usdPct ? 0 : 1)}% dto.',
      );
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Future<void> _openBulkUsdDiscountDialogImpl() async {
    final input = await ImporterBulkUsdDiscountDialog.show(context);
    if (input == null || !mounted) return;

    final scope = switch (input.scope) {
      ImporterBulkUsdDiscountScope.conDescuento => 'con_descuento',
      ImporterBulkUsdDiscountScope.todos => 'todos',
    };

    final scopeLabel = input.scope == ImporterBulkUsdDiscountScope.todos
        ? 'todos los productos'
        : 'productos con descuento USD previo';

    final pctLabel = input.pct.toStringAsFixed(
      input.pct.truncateToDouble() == input.pct ? 0 : 1,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar actualización'),
        content: Text(
          input.pct == 0
              ? 'Se quitará el descuento USD de $scopeLabel. '
                  'Los aliados ya no verán precio USD rebajado en esos productos.\n\n¿Continuar?'
              : 'Se aplicará $pctLabel % de descuento USD a $scopeLabel.\n\n¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, actualizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final count = await SupabaseService.importadorBulkSetUsdPaymentDiscount(
        pct: input.pct,
        scope: scope,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? input.pct == 0
                    ? 'Descuento USD eliminado en $count producto${count == 1 ? '' : 's'}.'
                    : 'Descuento USD actualizado en $count producto${count == 1 ? '' : 's'}.'
                : 'Ningún producto coincidió con el alcance elegido.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (count > 0) _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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

  void _enterDeleteSelection({PartModel? initial}) {
    setState(() {
      _selectionMode = _InventorySelectionMode.delete;
      _selectedIds.clear();
      if (initial != null) _selectedIds.add(initial.id);
    });
  }

  void _toggleSelectAllVisible() {
    if (_visibleParts.isEmpty) return;
    setState(() {
      final allSelected = _visibleParts.every((p) => _selectedIds.contains(p.id));
      if (allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_visibleParts.map((p) => p.id));
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

  Future<void> _applyBulkVisibility({required bool isActive}) async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    try {
      await SupabaseService.setProductsActiveBulk(
        productIds: ids,
        isActive: isActive,
      );
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _selectionMode = _InventorySelectionMode.none;
      });
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? 'Visibilidad activada en ${ids.length} productos.'
                : '${ids.length} productos en pausa (ocultos).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  Future<void> _toggleActive(PartModel part, bool value) async {
    setState(() => _togglingProductIds.add(part.id));
    try {
      await SupabaseService.setProductActive(
        productId: part.id,
        isActive: value,
      );
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
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
          ? 'Visible para aliados. Desactiva para pausar.'
          : 'En pausa (oculto). Activa para publicar.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.isActive ? 'Visible' : 'Pausa',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: p.isActive
                  ? AppColors.successGreen
                  : Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 2),
          SwitchTheme(
            data: SwitchThemeData(
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return Colors.grey.shade300;
                }
                return AppColors.brandOrange.withOpacity(0.85);
              }),
              trackOutlineWidth: WidgetStateProperty.all(1.8),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return Colors.grey.shade400;
                }
                if (states.contains(WidgetState.selected)) {
                  return AppColors.brandOrange;
                }
                return Colors.white;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.brandOrange.withOpacity(0.22);
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
        child: p.imagenUrl != null && p.imagenUrl!.isNotEmpty
            ? Image.network(
                p.imagenUrl!,
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
    final lowStock = p.stock < 5;
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
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${p.precio.toStringAsFixed(2)} USD lista',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.brandOrange,
              ),
            ),
            const SizedBox(width: 12),
            if (lowStock)
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.red.shade700,
              ),
            if (lowStock) const SizedBox(width: 4),
            Text(
              '${p.stock} u.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: lowStock ? Colors.red.shade800 : AppColors.textPrimary,
                fontSize: 14,
              ),
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
                color: Colors.teal.shade800,
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
                color: Colors.blue.shade800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductTile(PartModel p, {required bool desktop}) {
    return Material(
      color: Colors.white,
      borderRadius: AppDecorations.radius12,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppDecorations.radius12,
          border: Border.all(color: Colors.grey.shade200),
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
                        return AppColors.brandOrange;
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
                  tooltip: 'Eliminar producto',
                  onPressed: () => _deleteSingle(p),
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

  Widget _buildInventoryHeader({required bool isDesktop, required double hPad}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, isDesktop ? 4 : 8, hPad, 8),
          child: FutureBuilder<InventoryMetrics>(
                future: _metricsFuture,
                builder: (context, snap) {
                  final m = snap.data ?? InventoryMetrics.zero;
                  return Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Total',
                          value: '${m.totalProducts}',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          label: 'Sin stock',
                          value: '${m.outOfStock}',
                          icon: Icons.remove_shopping_cart_outlined,
                          highlight: m.outOfStock > 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          label: 'Pausados',
                          value: '${m.paused}',
                          icon: Icons.pause_circle_outline,
                          highlight: m.paused > 0,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const ImporterThirdPartyAdsCarousel(),
            const ImporterActivePromoBanner(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar en mi inventario…',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: AppDecorations.radius12,
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppDecorations.radius12,
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            onSubmitted: (_) => _reload(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.end,
                            children: _inventoryToolbarButtons(),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar en mi inventario…',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: AppColors.fieldFill,
                            border: OutlineInputBorder(
                              borderRadius: AppDecorations.radius12,
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _reload(),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          children: _inventoryToolbarButtons(),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
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
                      _reload();
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Filtros rápidos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Stock bajo (<5 u.)'),
                        selected: _filterLowStock,
                        onSelected: (v) {
                          setState(() => _filterLowStock = v);
                          _reload();
                        },
                        selectedColor:
                            AppColors.brandOrange.withOpacity(0.22),
                        checkmarkColor: AppColors.brandOrange,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _filterLowStock
                              ? AppColors.brandOrange
                              : AppColors.textPrimary,
                        ),
                        side: BorderSide(
                          color: _filterLowStock
                              ? AppColors.brandOrange
                              : Colors.grey.shade300,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Solo activos (visibles)'),
                        selected: _filterActiveOnly,
                        onSelected: (v) {
                          setState(() {
                            _filterActiveOnly = v;
                            if (v) _filterHidden = false;
                          });
                          _reload();
                        },
                        selectedColor:
                            AppColors.successGreen.withOpacity(0.28),
                        checkmarkColor: AppColors.successGreen,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _filterActiveOnly
                              ? AppColors.successGreen
                              : AppColors.textPrimary,
                        ),
                        side: BorderSide(
                          color: _filterActiveOnly
                              ? AppColors.successGreen
                              : Colors.grey.shade300,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Solo ocultos (pausa)'),
                        selected: _filterHidden,
                        onSelected: (v) {
                          setState(() {
                            _filterHidden = v;
                            if (v) _filterActiveOnly = false;
                          });
                          _reload();
                        },
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange.shade900,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _filterHidden
                              ? Colors.orange.shade900
                              : AppColors.textPrimary,
                        ),
                        side: BorderSide(
                          color: _filterHidden
                              ? Colors.orange.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  TextButton.icon(
                    onPressed: () => _reload(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar lista'),
                  ),
                  TextButton.icon(
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
                          ? 'Cancelar eliminación'
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
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          ),
        ),
      ];
    }
    if (snapshot.hasError) {
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

    final parts = snapshot.data ?? [];
    if (snapshot.hasData &&
        (parts.length != _visibleParts.length ||
            parts.any((p) => !_visibleParts.any((v) => v.id == p.id)))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visibleParts = parts);
      });
    }

    if (parts.isEmpty) {
      final hasFilters = _filterLowStock ||
          _filterHidden ||
          _filterActiveOnly ||
          _categoryFilter != 'Todas' ||
          _searchController.text.trim().isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Text(
                hasFilters
                    ? 'Sin resultados con los filtros actuales. Prueba quitar filtros o actualizar.'
                    : 'Aún no tienes productos. Añade uno o importa Excel.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, listBottomPadding),
        sliver: SliverList.separated(
          itemCount: parts.length,
          separatorBuilder: (_, __) => SizedBox(height: isDesktop ? 10 : 8),
          itemBuilder: (context, i) =>
              _buildProductTile(parts[i], desktop: isDesktop),
        ),
      ),
    ];
  }

  Widget _buildSelectionBottomBar({required bool isDesktop}) {
    final allSelected = _visibleParts.isNotEmpty &&
        _visibleParts.every((p) => _selectedIds.contains(p.id));
    final isDelete = _selectionMode == _InventorySelectionMode.delete;
    final hint = isDelete
        ? 'Toca filas o mantén pulsado para elegir productos a eliminar.'
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
                      if (_visibleParts.isNotEmpty)
                        TextButton(
                          onPressed: _toggleSelectAllVisible,
                          child: Text(allSelected ? 'Quitar todo' : 'Seleccionar todo'),
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
                backgroundColor: AppColors.brandOrange,
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDecorations.radius12,
        border: Border.all(
          color: highlight
              ? AppColors.brandOrange.withOpacity(0.5)
              : Colors.grey.shade200,
        ),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.brandBlue),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
