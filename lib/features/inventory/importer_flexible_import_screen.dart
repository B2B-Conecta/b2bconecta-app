import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'catalog_import/catalog_import_field.dart';
import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'catalog_import_orchestrator.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'catalog_import_header_guess.dart';
import 'product_custom_fields.dart';
import 'importer_import_visibility_section.dart';
import 'product_custom_fields_section.dart';

/// Wizard de carga masiva: mapeo dinámico de columnas ERP → B2B Conecta.
class ImporterFlexibleImportScreen extends StatefulWidget {
  const ImporterFlexibleImportScreen({
    super.key,
    required this.fileName,
    required this.bytes,
    required this.fileMeta,
    required this.preview,
    required this.pagoSoloDivisas,
  });

  final String fileName;
  final Uint8List bytes;
  final CatalogImportFileMeta fileMeta;
  final CatalogImportPreview preview;
  final bool pagoSoloDivisas;

  static Future<CatalogImportResult?> open(
    BuildContext context, {
    required String fileName,
    required Uint8List bytes,
    required CatalogImportFileMeta fileMeta,
    required CatalogImportPreview preview,
    required bool pagoSoloDivisas,
  }) {
    return Navigator.of(context).push<CatalogImportResult>(
      MaterialPageRoute(
        builder: (_) => ImporterFlexibleImportScreen(
          fileName: fileName,
          bytes: bytes,
          fileMeta: fileMeta,
          preview: preview,
          pagoSoloDivisas: pagoSoloDivisas,
        ),
      ),
    );
  }

  @override
  State<ImporterFlexibleImportScreen> createState() =>
      _ImporterFlexibleImportScreenState();
}

class _ImporterFlexibleImportScreenState
    extends State<ImporterFlexibleImportScreen> {
  late final Map<String, String?> _columnSelections;
  CatalogImportUpsertMode _upsertMode = CatalogImportUpsertMode.updateAll;
  bool _dryRun = false;
  bool _captureUnmapped = true;
  bool _decimalCommaOnPrice = false;
  ImporterNewProductsVisibility _newProductsVisibility =
      ImporterNewProductsVisibility.paused;
  bool _importing = false;
  bool _optionalExpanded = false;
  bool _advancedOptionsExpanded = false;
  bool _erpSectionExpanded = false;
  bool _previewExpanded = false;
  final List<ImportCustomFieldMappingRow> _customFieldMappings = [];
  int _processedRows = 0;
  int _lastProgressUiUpdateMs = 0;
  CatalogImportResult? _partial;

  static const _maxContentWidth = 1180.0;

  static const _optionalFields = [
    CatalogImportField.description,
    CatalogImportField.salePriceUsd,
    CatalogImportField.category,
    CatalogImportField.compatibility,
    CatalogImportField.imageUrl,
    CatalogImportField.hasWarranty,
    CatalogImportField.usdPaymentDiscountPct,
    CatalogImportField.volumeTiersJson,
  ];

  static const _fieldHintsVe = <CatalogImportField, String>{
    CatalogImportField.sku:
        'Código de artículo de tu facturación o ERP (debe ser único por repuesto).',
    CatalogImportField.name:
        'Nombre comercial que verán los aliados en el catálogo.',
    CatalogImportField.description:
        'Detalle técnico, referencia OEM o notas del repuesto.',
    CatalogImportField.priceUsd:
        'Precio mayorista en dólares (USD). B2B Conecta no convierte a Bs en la importación.',
    CatalogImportField.salePriceUsd:
        'Precio promocional en USD, si aplica. Debe ser menor al precio de lista.',
    CatalogImportField.stock:
        'Unidades disponibles en tu almacén o sucursal.',
    CatalogImportField.category:
        'Familia o línea (Motor, Frenos, Eléctrico, etc.).',
    CatalogImportField.compatibility:
        'Modelos de moto compatibles (ej. CG150, Bera 150).',
    CatalogImportField.imageUrl:
        'Enlace público a la foto del repuesto.',
    CatalogImportField.hasWarranty:
        'Usa si/no, o días numéricos del ERP (ej. 30, 90 días).',
    CatalogImportField.usdPaymentDiscountPct:
        '% de descuento adicional si el aliado paga en divisas.',
    CatalogImportField.volumeTiersJson:
        'Tramos por volumen en JSON (configuración avanzada).',
  };

  static String _labelVe(CatalogImportField field) => switch (field) {
        CatalogImportField.sku => 'Código / SKU',
        CatalogImportField.name => 'Nombre del repuesto',
        CatalogImportField.description => 'Descripción',
        CatalogImportField.priceUsd => 'Precio mayorista (USD)',
        CatalogImportField.salePriceUsd => 'Precio oferta (USD)',
        CatalogImportField.stock => 'Existencia / stock',
        CatalogImportField.category => 'Categoría',
        CatalogImportField.compatibility => 'Compatibilidad',
        CatalogImportField.imageUrl => 'URL de imagen',
        CatalogImportField.hasWarranty => 'Garantía',
        CatalogImportField.usdPaymentDiscountPct => 'Descuento pago en USD (%)',
        CatalogImportField.volumeTiersJson => 'Tramos por volumen (JSON)',
      };

  @override
  void initState() {
    super.initState();
    final guessed = CatalogImportHeaderGuess.suggestAll(widget.preview.headers);
    _columnSelections = {
      for (final f in CatalogImportField.values) f.key: guessed[f.key],
    };
    _decimalCommaOnPrice = _sampleUsesDecimalComma();
    _seedCustomFieldMappings();
  }

  void _seedCustomFieldMappings() {
    _customFieldMappings.clear();
    // Las columnas extra se guardan con «Guardar columnas adicionales» activo.
  }

  List<String> _unmappedHeaders() {
    return unmappedFileHeaders(
      headers: widget.preview.headers,
      coreColumnSelections: _columnSelections,
      customColumnSelections: {
        for (final row in _customFieldMappings)
          if (row.sourceColumn != null) row.fieldLabel: row.sourceColumn,
      },
    );
  }

  Map<String, CatalogImportColumnBinding> _buildCustomFieldsMap() {
    final map = <String, CatalogImportColumnBinding>{};
    for (final row in _customFieldMappings) {
      final label = row.fieldLabel.trim();
      final source = row.sourceColumn?.trim();
      if (label.isEmpty || source == null || source.isEmpty) continue;
      map[slugProductCustomFieldKey(label)] = CatalogImportColumnBinding(
        source: source,
      );
    }
    return map;
  }

  Set<String> _buildAliadoVisibleCustomFieldKeys() {
    final keys = <String>{};
    for (final row in _customFieldMappings) {
      if (!row.visibleToAliado) continue;
      final label = row.fieldLabel.trim();
      final source = row.sourceColumn?.trim();
      if (label.isEmpty || source == null || source.isEmpty) continue;
      keys.add(slugProductCustomFieldKey(label));
    }
    return keys;
  }

  void _syncCustomFieldsAfterCoreChange() {
    final unmapped = _unmappedHeaders();
    _customFieldMappings.removeWhere(
      (row) =>
          row.sourceColumn != null &&
          !unmapped.contains(row.sourceColumn) &&
          !_erpMappedSources.contains(row.sourceColumn),
    );
  }

  void _addErpFieldFromColumn(String header) {
    if (_erpMappedSources.contains(header) ||
        _coreMappedSources.contains(header)) {
      return;
    }
    setState(() {
      _customFieldMappings.add(
        ImportCustomFieldMappingRow(
          fieldLabel: formatProductCustomFieldLabel(
            slugProductCustomFieldKey(header),
          ),
          sourceColumn: header,
        ),
      );
    });
  }

  bool _sampleUsesDecimalComma() {
    final priceCol = _columnSelections[CatalogImportField.priceUsd.key];
    if (priceCol == null) return false;
    for (final row in widget.preview.sampleRows) {
      final v = row[priceCol] ?? '';
      if (RegExp(r'\d+,\d+').hasMatch(v)) return true;
    }
    return false;
  }

  Set<String> get _mappedSources => {
        ..._columnSelections.values.whereType<String>().where((s) => s.isNotEmpty),
        ..._customFieldMappings
            .map((r) => r.sourceColumn)
            .whereType<String>()
            .where((s) => s.isNotEmpty),
      };

  Set<String> get _coreMappedSources => _columnSelections.values
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet();

  Set<String> get _erpMappedSources => _customFieldMappings
      .map((r) => r.sourceColumn)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet();

  int get _mappedRequiredCount => catalogImportRequiredFields
      .where((f) => (_columnSelections[f.key] ?? '').isNotEmpty)
      .length;

  CatalogImportMapping _buildMapping() {
    final columnMap = <String, CatalogImportColumnBinding>{};
    for (final field in CatalogImportField.values) {
      final source = _columnSelections[field.key];
      if (source == null || source.isEmpty) continue;

      var transform = CatalogImportTransform.none;
      if (field == CatalogImportField.priceUsd ||
          field == CatalogImportField.salePriceUsd ||
          field == CatalogImportField.usdPaymentDiscountPct) {
        if (_decimalCommaOnPrice) {
          transform = CatalogImportTransform.decimalComma;
        }
      } else if (field == CatalogImportField.hasWarranty) {
        transform = CatalogImportTransform.booleanSiNo;
      }

      columnMap[field.key] = CatalogImportColumnBinding(
        source: source,
        required: field.isRequired,
        transform: transform,
      );
    }

    return CatalogImportMapping(
      file: widget.fileMeta,
      options: CatalogImportOptions(
        upsertMode: _upsertMode,
        dryRun: _dryRun,
        newProductsActive: _newProductsVisibility.isActive,
        pagoSoloDivisas: widget.pagoSoloDivisas,
      ),
      columnMap: columnMap,
      customFieldsMap: _buildCustomFieldsMap(),
      aliadoVisibleCustomFieldKeys: _buildAliadoVisibleCustomFieldKeys(),
      unmappedColumnsPolicy: _captureUnmapped
          ? CatalogUnmappedColumnsPolicy.captureAsCustom
          : CatalogUnmappedColumnsPolicy.ignore,
    );
  }

  Future<void> _runImport() async {
    final mapping = _buildMapping();
    final missing = mapping.missingRequiredFields();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Completa el mapeo de: ${missing.join(', ')}',
          ),
        ),
      );
      return;
    }

    setState(() {
      _importing = true;
      _processedRows = 0;
      _partial = null;
    });

    try {
      final result = await CatalogImportOrchestrator.execute(
        bytes: widget.bytes,
        mapping: mapping,
        onProgress: (rows, partial) {
          if (!mounted) return;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastProgressUiUpdateMs < 120 && rows < (widget.preview.totalDataRowsEstimate ?? rows)) {
            return;
          }
          _lastProgressUiUpdateMs = now;
          setState(() {
            _processedRows = rows;
            _partial = partial;
          });
        },
      );

      if (!mounted) return;
      setState(() => _importing = false);
      await _showResultDialog(result);
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar: $e')),
      );
    }
  }

  Future<void> _showResultDialog(CatalogImportResult result) async {
    final errors = result.allErrors.take(20).toList();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          result.dryRun ? 'Revisión completada' : 'Importación completada',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!result.dryRun) ...[
                Text('Repuestos nuevos: ${result.inserted}'),
                Text('Repuestos actualizados: ${result.updated}'),
                Text('Filas omitidas: ${result.skipped}'),
              ] else
                Text(
                  'Filas válidas (sin guardar): ${result.skipped}',
                ),
              Text('Errores detectados: ${result.errorCount}'),
              if (!result.dryRun && result.inserted > 0 &&
                  !_newProductsVisibility.isActive) ...[
                const SizedBox(height: 10),
                Text(
                  'Los repuestos nuevos quedan en pausa (ocultos para aliados). '
                  'Actívalos en Mi inventario cuando quieras publicarlos.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.brandAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Detalle (primeros 20):',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...errors.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Fila ${e.rowIndex}${e.sku != null ? ' · ${e.sku}' : ''}: '
                      '${e.message}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  static String _upsertModeLabel(
    CatalogImportUpsertMode mode, {
    bool compact = false,
  }) =>
      switch (mode) {
        CatalogImportUpsertMode.updateAll => compact
            ? 'Actualizar todo'
            : 'Actualizar nombre, precio, stock y demás campos',
        CatalogImportUpsertMode.priceStockOnly => compact
            ? 'Solo precio y stock'
            : 'Solo actualizar precio en USD y existencia',
        CatalogImportUpsertMode.insertOnly => compact
            ? 'Solo códigos nuevos'
            : 'No tocar existentes; solo cargar códigos nuevos',
      };

  static String _upsertModeDescription(CatalogImportUpsertMode mode) =>
      switch (mode) {
        CatalogImportUpsertMode.updateAll =>
            'Sobrescribe nombre, precio en USD, existencia y demás datos mapeados.',
        CatalogImportUpsertMode.priceStockOnly =>
            'Ideal para actualizar listas de precios sin cambiar fichas ya publicadas.',
        CatalogImportUpsertMode.insertOnly =>
            'Útil para ampliar catálogo sin modificar repuestos que ya vendes.',
      };

  IconData _upsertModeIcon(CatalogImportUpsertMode mode) => switch (mode) {
        CatalogImportUpsertMode.updateAll => Icons.sync,
        CatalogImportUpsertMode.priceStockOnly => Icons.payments_outlined,
        CatalogImportUpsertMode.insertOnly => Icons.playlist_add,
      };

  Widget _fieldDropdown(CatalogImportField field, {bool compact = false}) {
    final isRequired = field.isRequired;
    final hint = _fieldHintsVe[field];
    final label = _labelVe(field);

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String?>(
            value: _columnSelections[field.key],
            isExpanded: true,
            decoration: InputDecoration(
              labelText: label + (isRequired ? ' *' : ''),
              filled: true,
              fillColor: isRequired
                  ? AppColors.brandBlueContainer.withOpacity(0.5)
                  : AppColors.fieldFill,
              border: OutlineInputBorder(
                borderRadius: AppDecorations.radius12,
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            hint: Text(
              isRequired ? 'Elige una columna de tu archivo' : 'No mapear',
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              if (!isRequired)
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— No mapear —'),
                ),
              ...widget.preview.headers.map(
                (h) => DropdownMenuItem<String?>(
                  value: h,
                  child: Row(
                    children: [
                      Icon(
                        Icons.view_column_outlined,
                        size: 16,
                        color: _mappedSources.contains(h)
                            ? AppColors.brandBlue
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(h, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: _importing
                ? null
                : (v) => setState(() {
                      _columnSelections[field.key] = v;
                      _syncCustomFieldsAfterCoreChange();
                    }),
          ),
          if (hint != null && !compact)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
    IconData? icon,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceTinted,
      shape: RoundedRectangleBorder(
        borderRadius: AppDecorations.radius12,
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppColors.brandBlue),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _fileSummaryCard() {
    final estimate = widget.preview.totalDataRowsEstimate;
    final ext = widget.fileMeta.format == CatalogImportFileFormat.csv
        ? 'CSV'
        : 'Excel';

    return _sectionCard(
      icon: Icons.description_outlined,
      title: widget.fileName,
      subtitle:
          '$ext · ${widget.preview.headers.length} columnas · '
          '${estimate ?? '?'} repuestos aprox.',
      child: const Text(
        'Exporta tu listado tal como sale del ERP. B2B Conecta reconoce '
        'automáticamente SKU, nombre, precio y stock.',
        style: TextStyle(fontSize: 12.5, height: 1.45),
      ),
    );
  }

  Widget _autoMapReadyBanner() {
    final ready =
        _mappedRequiredCount == catalogImportRequiredFields.length;
    if (!ready) return const SizedBox.shrink();

    final autoExtras = _captureUnmapped ? _unmappedHeaders().length : 0;
    final detail = autoExtras > 0
        ? ' Detectamos los 4 campos obligatorios. '
            '$autoExtras columna(s) extra se guardarán como datos internos.'
        : ' Detectamos SKU, nombre, precio y stock. Revisa y toca Importar.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.1),
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: AppColors.successGreen.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.successGreen,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              detail,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.green.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collapsiblePanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool expanded,
    required ValueChanged<bool> onExpandedChanged,
    required Widget child,
  }) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: AppDecorations.radius12,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppDecorations.radius12,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: expanded,
            onExpansionChanged: onExpandedChanged,
            tilePadding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: Icon(icon, color: AppColors.brandBlue, size: 22),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
            children: [child],
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator({required bool desktop}) {
    final step1Done = _mappedRequiredCount == catalogImportRequiredFields.length;
    final step2Count = _customFieldMappings
        .where((r) => (r.fieldLabel.trim().isNotEmpty) && r.sourceColumn != null)
        .length;
    final autoCount =
        _captureUnmapped ? _unmappedHeaders().length : 0;

    Widget step(int n, String label, String detail, bool done) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: done
                ? AppColors.brandBlueContainer.withOpacity(0.55)
                : AppColors.fieldFill,
            borderRadius: AppDecorations.radius12,
            border: Border.all(
              color: done
                  ? AppColors.brandBlue.withOpacity(0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor:
                    done ? AppColors.brandBlue : AppColors.textSecondary,
                child: Text(
                  '$n',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: desktop ? 13 : 12,
                      ),
                    ),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        step(
          1,
          'Columnas clave',
          '$_mappedRequiredCount/4 listas',
          step1Done,
        ),
        const SizedBox(width: 8),
        step(
          2,
          'Extras ERP',
          step2Count > 0
              ? '$step2Count manual(es)'
              : autoCount > 0
                  ? '$autoCount auto'
                  : 'Opcional',
          step2Count > 0 || (_captureUnmapped && autoCount > 0),
        ),
        const SizedBox(width: 8),
        step(3, 'Confirmar', _dryRun ? 'Simulación' : 'Importar', step1Done),
      ],
    );
  }

  Widget _coreMappingCard({required bool desktop}) {
    final optionalFields = _optionalFields
        .where((f) =>
            f != CatalogImportField.usdPaymentDiscountPct ||
            !widget.pagoSoloDivisas)
        .toList();

    Widget requiredGrid() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final twoCol = desktop && constraints.maxWidth >= 520;
          final itemWidth =
              twoCol ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

          Widget field(CatalogImportField f) => SizedBox(
                width: itemWidth,
                child: _fieldDropdown(f, compact: twoCol),
              );

          if (!twoCol) {
            return Column(
              children: catalogImportRequiredFields.map(field).toList(),
            );
          }
          return Wrap(
            spacing: 12,
            runSpacing: 0,
            children: catalogImportRequiredFields.map(field).toList(),
          );
        },
      );
    }

    return _sectionCard(
      icon: Icons.storefront_outlined,
      title: 'Asocia tus columnas',
      subtitle:
          'SKU, nombre, precio y stock son obligatorios. El resto es opcional.',
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Obligatorios',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              requiredGrid(),
              const SizedBox(height: 4),
              Material(
                color: AppColors.fieldFill,
                borderRadius: AppDecorations.radius12,
                child: InkWell(
                  borderRadius: AppDecorations.radius12,
                  onTap: _importing
                      ? null
                      : () => setState(
                            () => _optionalExpanded = !_optionalExpanded,
                          ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Campos opcionales',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(
                          _optionalExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_optionalExpanded) ...[
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoCol = desktop && constraints.maxWidth >= 520;
                    final itemWidth = twoCol
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;

                    Widget field(CatalogImportField f) => SizedBox(
                          width: itemWidth,
                          child: _fieldDropdown(f, compact: twoCol),
                        );

                    if (!twoCol) {
                      return Column(
                        children: optionalFields.map(field).toList(),
                      );
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 0,
                      children: optionalFields.map(field).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
    );
  }

  Widget _customFieldsMappingCard({required bool desktop, bool bare = false}) {
    final content = _customFieldsMappingContent(desktop: desktop);
    if (bare) return content;

    return _sectionCard(
      icon: Icons.dataset_outlined,
      title: 'Datos extra del ERP (opcional)',
      subtitle: _captureUnmapped && _unmappedHeaders().isNotEmpty
          ? '${_unmappedHeaders().length} columna(s) se guardarán automáticamente. '
              'Puedes mapear manualmente abajo o dejar que B2B Conecta las capture.'
          : 'Marca, ubicación, código de barras… Usa el ojo para visibilidad aliado.',
      child: content,
    );
  }

  Widget _customFieldsMappingContent({required bool desktop}) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _unmappedColumnsBanner(),
          if (_customFieldMappings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: _importing
                      ? null
                      : () => setState(() {
                            for (final r in _customFieldMappings) {
                              r.visibleToAliado = false;
                            }
                          }),
                  icon: const Icon(Icons.lock_outline, size: 16),
                  label: const Text('Ocultar todos para aliados'),
                ),
                OutlinedButton.icon(
                  onPressed: _importing
                      ? null
                      : () => setState(() {
                            for (final r in _customFieldMappings) {
                              r.visibleToAliado = true;
                            }
                          }),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Mostrar todos a aliados'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_customFieldMappings.isEmpty && _unmappedHeaders().isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: AppDecorations.radius12,
              ),
              child: const Text(
                'No hay columnas adicionales sugeridas. Usa «Agregar campo» '
                'o activa «Guardar columnas adicionales» para capturar el resto '
                'automáticamente al importar.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ...List.generate(_customFieldMappings.length, (i) {
            final row = _customFieldMappings[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: row.visibleToAliado
                        ? 'Visible para aliados (tocar para ocultar)'
                        : 'Solo interno (tocar para mostrar a aliados)',
                    onPressed: _importing
                        ? null
                        : () => setState(() {
                              row.visibleToAliado = !row.visibleToAliado;
                            }),
                    icon: Icon(
                      row.visibleToAliado
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: row.visibleToAliado
                          ? AppColors.successGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    flex: desktop ? 4 : 5,
                    child: TextFormField(
                      initialValue: row.fieldLabel,
                      decoration: InputDecoration(
                        labelText: 'Nombre en inventario',
                        hintText: 'Ej. Marca',
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: AppDecorations.radius12,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => row.fieldLabel = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: desktop ? 5 : 6,
                    child: DropdownButtonFormField<String?>(
                      value: row.sourceColumn,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Columna del archivo',
                        filled: true,
                        fillColor: AppColors.fieldFill,
                        border: OutlineInputBorder(
                          borderRadius: AppDecorations.radius12,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: widget.preview.headers
                          .map(
                            (h) => DropdownMenuItem<String?>(
                              value: h,
                              child: Text(h, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: _importing
                          ? null
                          : (v) => setState(() => row.sourceColumn = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar',
                    onPressed: _importing
                        ? null
                        : () => setState(() {
                              _customFieldMappings.removeAt(i);
                            }),
                    icon: Icon(Icons.close, color: Colors.red.shade400),
                  ),
                ],
              ),
            );
          }),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _importing
                    ? null
                    : () => setState(() {
                          _customFieldMappings.add(
                            ImportCustomFieldMappingRow(fieldLabel: ''),
                          );
                        }),
                icon: const Icon(Icons.add),
                label: const Text('Agregar campo'),
              ),
              TextButton.icon(
                onPressed: _importing
                    ? null
                    : () => setState(() {
                          for (final h in _unmappedHeaders()) {
                            final exists = _customFieldMappings.any(
                              (r) => r.sourceColumn == h,
                            );
                            if (exists) continue;
                            _customFieldMappings.add(
                              ImportCustomFieldMappingRow(
                                fieldLabel: formatProductCustomFieldLabel(
                                  slugProductCustomFieldKey(h),
                                ),
                                sourceColumn: h,
                              ),
                            );
                          }
                        }),
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Sugerir columnas libres'),
              ),
            ],
          ),
        ],
    );
  }

  Widget _unmappedColumnsBanner() {
    final unmapped = _unmappedHeaders();
    if (unmapped.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withOpacity(0.08),
          borderRadius: AppDecorations.radius12,
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.successGreen, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Todas las columnas del archivo están asociadas.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Columnas sin asignar (${unmapped.length})',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: unmapped.map((h) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(h, style: const TextStyle(fontSize: 11.5)),
              onPressed:
                  _importing ? null : () => _addErpFieldFromColumn(h),
            );
          }).toList(),
        ),
        if (_captureUnmapped) ...[
          const SizedBox(height: 8),
          Text(
            'O se guardarán automáticamente al importar (toggle en paso 3).',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.brandAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _upsertModeDropdown({required bool compact}) {
    return DropdownButtonFormField<CatalogImportUpsertMode>(
      value: _upsertMode,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Si el código ya está en tu inventario',
        filled: true,
        fillColor: AppColors.fieldFill,
        border: OutlineInputBorder(
          borderRadius: AppDecorations.radius12,
          borderSide: BorderSide.none,
        ),
      ),
      selectedItemBuilder: (context) => [
        CatalogImportUpsertMode.updateAll,
        CatalogImportUpsertMode.priceStockOnly,
        CatalogImportUpsertMode.insertOnly,
      ]
          .map(
            (mode) => Text(
              _upsertModeLabel(mode, compact: compact),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          )
          .toList(),
      items: [
        for (final mode in CatalogImportUpsertMode.values)
          DropdownMenuItem(
            value: mode,
            child: Text(_upsertModeLabel(mode)),
          ),
      ],
      onChanged: _importing
          ? null
          : (v) {
              if (v != null) setState(() => _upsertMode = v);
            },
    );
  }

  Widget _upsertModeCards() {
    const modes = [
      CatalogImportUpsertMode.updateAll,
      CatalogImportUpsertMode.priceStockOnly,
      CatalogImportUpsertMode.insertOnly,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final threeCol = constraints.maxWidth >= 860;
        final tileWidth = threeCol
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: modes.map((mode) {
            final selected = _upsertMode == mode;
            return SizedBox(
              width: tileWidth,
              child: Material(
                color: selected
                    ? AppColors.brandBlueContainer.withOpacity(0.65)
                    : AppColors.fieldFill,
                borderRadius: AppDecorations.radius12,
                child: InkWell(
                  borderRadius: AppDecorations.radius12,
                  onTap: _importing
                      ? null
                      : () => setState(() => _upsertMode = mode),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: AppDecorations.radius12,
                      border: Border.all(
                        color: selected
                            ? AppColors.brandBlue.withOpacity(0.55)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.brandBlue.withOpacity(0.12)
                                : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _upsertModeIcon(mode),
                            size: 20,
                            color: selected
                                ? AppColors.brandBlue
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _upsertModeLabel(mode, compact: true),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _upsertModeDescription(mode),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Radio<CatalogImportUpsertMode>(
                          value: mode,
                          groupValue: _upsertMode,
                          onChanged: _importing
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setState(() => _upsertMode = v);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _optionsCard({required bool desktop}) {
    final optionTiles = [
      _ImportOptionTileData(
        icon: Icons.price_change_outlined,
        title: 'Montos con coma decimal',
        subtitle:
            'Actívalo si tu Excel muestra precios como 12,50 (habitual en '
            'exportaciones venezolanas).',
        value: _decimalCommaOnPrice,
        onChanged: _importing
            ? null
            : (v) => setState(() => _decimalCommaOnPrice = v),
      ),
      _ImportOptionTileData(
        icon: Icons.library_add_outlined,
        title: 'Guardar columnas adicionales',
        subtitle:
            'Si una columna no la mapeas arriba, se guarda automáticamente '
            'con el nombre de la columna del Excel.',
        value: _captureUnmapped,
        onChanged: _importing
            ? null
            : (v) => setState(() => _captureUnmapped = v),
      ),
      _ImportOptionTileData(
        icon: Icons.fact_check_outlined,
        title: 'Revisar sin guardar',
        subtitle:
            'Valida el archivo y muestra errores antes de modificar tu '
            'inventario en B2B Conecta.',
        value: _dryRun,
        onChanged: _importing ? null : (v) => setState(() => _dryRun = v),
      ),
    ];

    return _sectionCard(
      icon: Icons.tune,
      title: 'Confirmar importación',
      subtitle: 'Reglas para códigos repetidos y productos nuevos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _OptionsSubheading(
            title: 'Códigos ya registrados',
            hint: 'Qué hacer si el SKU del archivo ya está en tu inventario',
          ),
          const SizedBox(height: 10),
          if (desktop)
            _upsertModeCards()
          else
            _upsertModeDropdown(compact: true),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const _OptionsSubheading(
            title: 'Productos nuevos',
            hint: 'Visibilidad para aliados de códigos que aún no están en inventario',
          ),
          const SizedBox(height: 10),
          if (desktop)
            ImporterNewProductsVisibilitySection(
              value: _newProductsVisibility,
              enabled: !_importing,
              onChanged: (v) => setState(() => _newProductsVisibility = v),
            )
          else
            ImporterNewProductsVisibilitySection(
              value: _newProductsVisibility,
              enabled: !_importing,
              compact: true,
              onChanged: (v) => setState(() => _newProductsVisibility = v),
            ),
          const SizedBox(height: 20),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _advancedOptionsExpanded,
              onExpansionChanged: (v) =>
                  setState(() => _advancedOptionsExpanded = v),
              title: const Text(
                'Opciones avanzadas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: const Text(
                'Coma decimal, columnas extra automáticas, simulación',
                style: TextStyle(fontSize: 11.5),
              ),
              children: [
                const SizedBox(height: 8),
                if (desktop)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final threeCol = constraints.maxWidth >= 860;
                      final tileWidth = threeCol
                          ? (constraints.maxWidth - 24) / 3
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: optionTiles
                            .map(
                              (tile) => SizedBox(
                                width: tileWidth,
                                child: _ImportOptionTile(data: tile),
                              ),
                            )
                            .toList(),
                      );
                    },
                  )
                else
                  ...optionTiles.map((tile) => _ImportOptionTile(data: tile)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewPanel() {
    return _sectionCard(
      icon: Icons.table_chart_outlined,
      title: 'Vista previa del archivo',
      subtitle:
          'Azul = catálogo B2B Conecta · Azul acento = dato ERP · Gris = sin asignar',
      child: _PreviewTable(
        headers: widget.preview.headers,
        rows: widget.preview.sampleRows,
        coreHeaders: _coreMappedSources,
        erpHeaders: _erpMappedSources,
      ),
    );
  }

  Widget _actionBar({required bool desktop}) {
    final ready = _mappedRequiredCount == catalogImportRequiredFields.length;
    final statusText = ready
        ? 'Listo para importar · ${widget.preview.totalDataRowsEstimate ?? '?'} filas estimadas'
        : 'Faltan campos obligatorios por asociar';

    final importButton = FilledButton.icon(
      onPressed: _importing || !ready ? null : _runImport,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
      icon: Icon(_dryRun ? Icons.fact_check_outlined : Icons.upload),
      label: Text(_dryRun ? 'Simular importación' : 'Importar inventario'),
    );

    return Material(
      elevation: desktop ? 4 : 0,
      color: AppColors.surfaceTinted,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 24 : 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.black.withOpacity(0.08)),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: desktop
                ? Row(
                    children: [
                      Icon(
                        ready ? Icons.check_circle : Icons.info_outline,
                        color: ready
                            ? AppColors.successGreen
                            : AppColors.brandAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 13,
                            color: ready
                                ? AppColors.successGreen
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      importButton,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ready ? Icons.check_circle : Icons.info_outline,
                            color: ready
                                ? AppColors.successGreen
                                : AppColors.brandAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: ready
                                    ? AppColors.successGreen
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      importButton,
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool desktop) {
    final horizontal = desktop ? 24.0 : 16.0;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fileSummaryCard(),
                    const SizedBox(height: 12),
                    _stepIndicator(desktop: desktop),
                    const SizedBox(height: 12),
                    _autoMapReadyBanner(),
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _coreMappingCard(desktop: true),
                                const SizedBox(height: 14),
                                _optionsCard(desktop: true),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 11,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _previewPanel(),
                                const SizedBox(height: 14),
                                _customFieldsMappingCard(desktop: true),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _coreMappingCard(desktop: false),
                      const SizedBox(height: 14),
                      _optionsCard(desktop: false),
                      const SizedBox(height: 14),
                      _collapsiblePanel(
                        title: 'Vista previa',
                        subtitle: 'Primeras filas del archivo',
                        icon: Icons.table_chart_outlined,
                        expanded: _previewExpanded,
                        onExpandedChanged: (v) =>
                            setState(() => _previewExpanded = v),
                        child: _PreviewTable(
                          headers: widget.preview.headers,
                          rows: widget.preview.sampleRows,
                          coreHeaders: _coreMappedSources,
                          erpHeaders: _erpMappedSources,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _collapsiblePanel(
                        title: 'Datos extra del ERP',
                        subtitle: _captureUnmapped &&
                                _unmappedHeaders().isNotEmpty
                            ? '${_unmappedHeaders().length} columna(s) auto'
                            : 'Opcional · mapeo manual',
                        icon: Icons.dataset_outlined,
                        expanded: _erpSectionExpanded,
                        onExpandedChanged: (v) =>
                            setState(() => _erpSectionExpanded = v),
                        child: _customFieldsMappingContent(desktop: false),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _actionBar(desktop: desktop),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.b2bDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceTinted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Carga masiva'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Tu Excel o CSV → inventario B2B Conecta en 3 pasos',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withOpacity(0.95),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildBody(desktop),
          if (_importing) _buildProgressOverlay(),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay() {
    final partial = _partial;
    final estimate = widget.preview.totalDataRowsEstimate;

    return ColoredBox(
      color: Colors.black.withOpacity(0.35),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _dryRun
                        ? 'Revisando archivo…'
                        : 'Cargando inventario…',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_processedRows de ${estimate ?? '?'} filas procesadas',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  if (partial != null) ...[
                    const SizedBox(height: 14),
                    Text('Nuevos: ${partial.inserted}'),
                    Text('Actualizados: ${partial.updated}'),
                    Text('Errores: ${partial.errorCount}'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionsSubheading extends StatelessWidget {
  const _OptionsSubheading({
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ImportOptionTileData {
  const _ImportOptionTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
}

class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({required this.data});

  final _ImportOptionTileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: data.value
            ? AppColors.brandAccent.withOpacity(0.08)
            : AppColors.fieldFill,
        borderRadius: AppDecorations.radius12,
        border: Border.all(
          color: data.value
              ? AppColors.brandAccent.withOpacity(0.45)
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              data.icon,
              size: 20,
              color: data.value ? AppColors.brandAccent : AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: data.value,
            onChanged: data.onChanged,
          ),
        ],
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({
    required this.headers,
    required this.rows,
    required this.coreHeaders,
    required this.erpHeaders,
  });

  final List<String> headers;
  final List<Map<String, String>> rows;
  final Set<String> coreHeaders;
  final Set<String> erpHeaders;

  Color _headerColor(String h) {
    if (coreHeaders.contains(h)) return AppColors.brandBlue;
    if (erpHeaders.contains(h)) return AppColors.brandAccent;
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const Text('No se detectaron columnas en el archivo.');
    }

    return ClipRRect(
      borderRadius: AppDecorations.radius12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          borderRadius: AppDecorations.radius12,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppColors.brandBlueContainer.withOpacity(0.4),
            ),
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 52,
            columnSpacing: 20,
            columns: headers.map((h) {
              final isCore = coreHeaders.contains(h);
              final isErp = erpHeaders.contains(h);
              return DataColumn(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCore || isErp)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          isCore ? Icons.storefront_outlined : Icons.dataset_outlined,
                          size: 14,
                          color: _headerColor(h),
                        ),
                      ),
                    Text(
                      h,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _headerColor(h),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            rows: rows
                .map(
                  (row) => DataRow(
                    cells: headers
                        .map(
                          (h) => DataCell(
                            Text(
                              row[h] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: coreHeaders.contains(h) ||
                                        erpHeaders.contains(h)
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
