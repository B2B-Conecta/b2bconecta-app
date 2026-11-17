import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'catalog_import/catalog_import_field.dart';
import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'catalog_import_orchestrator.dart';
import 'catalog_import_photo_review.dart';
import 'catalog_import_photos.dart';
import 'catalog_photo_adjustments.dart';
import 'catalog_photo_source.dart';
import 'catalog_workbook_photos.dart';
import 'product_image_bulk_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/excel_file_export.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'catalog_import_header_guess.dart';
import 'catalog_import_issue_scan.dart';
import 'catalog_import_preview_details_dialog.dart';
import 'catalog_import_validator.dart';
import 'flexible_catalog_import_service.dart';
import 'importer_import_review_panel.dart';
import 'product_min_order_qty.dart';
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
    this.documentPhotos,
    this.sourceRowOffset = 0,
  });

  final String fileName;
  final Uint8List bytes;
  final CatalogImportFileMeta fileMeta;
  final CatalogImportPreview preview;
  final bool pagoSoloDivisas;
  final CatalogPhotoSource? documentPhotos;
  final int sourceRowOffset;

  static Future<CatalogImportResult?> open(
    BuildContext context, {
    required String fileName,
    required Uint8List bytes,
    required CatalogImportFileMeta fileMeta,
    required CatalogImportPreview preview,
    required bool pagoSoloDivisas,
    CatalogPhotoSource? documentPhotos,
    int sourceRowOffset = 0,
  }) {
    return Navigator.of(context).push<CatalogImportResult>(
      MaterialPageRoute(
        builder: (_) => ImporterFlexibleImportScreen(
          fileName: fileName,
          bytes: bytes,
          fileMeta: fileMeta,
          preview: preview,
          pagoSoloDivisas: pagoSoloDivisas,
          documentPhotos: documentPhotos,
          sourceRowOffset: sourceRowOffset,
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
  String _progressLabel = 'Revisando archivo…';
  final _corrections = <int, Map<String, String>>{};
  List<CatalogPhotoDraft> _photos = [];
  List<String> _invalidPhotoFiles = [];
  late CatalogPhotoSource? _workbookPhotos = widget.documentPhotos;
  bool _workbookReviewed = false;
  bool _readingWorkbookPhotos = false;
  String? _photoZipName;
  bool _captureUnmapped = true;
  bool _decimalCommaOnPrice = false;
  ImporterNewProductsVisibility _newProductsVisibility =
      ImporterNewProductsVisibility.paused;
  bool _importing = false;
  bool _savingPhotos = false;
  bool _cancelRequested = false;
  int? _emptyStockFill;
  double? _emptyPriceFill;
  CatalogImportResult? _lastDryRun;
  String? _lastDryRunKey;
  bool _previewExpanded = false;
  final _mappingCardKey = GlobalKey();
  final _previewCardKey = GlobalKey();
  int _previewRowLimit = catalogMappingPreviewInitialRows;
  double _previewTableHeight = catalogMappingPreviewInitialHeight;
  final List<ImportCustomFieldMappingRow> _customFieldMappings = [];
  int _processedRows = 0;
  int _lastProgressUiUpdateMs = 0;
  CatalogImportResult? _partial;

  static const _maxContentWidth = 1180.0;

  static const _optionalFields = [
    CatalogImportField.minOrderQty,
    CatalogImportField.description,
    CatalogImportField.salePriceUsd,
    CatalogImportField.category,
    CatalogImportField.compatibility,
    CatalogImportField.imageUrl,
    CatalogImportField.hasWarranty,
    CatalogImportField.isActive,
    CatalogImportField.parentSku,
    CatalogImportField.variantAttributeName,
    CatalogImportField.variantAttributeValue,
    CatalogImportField.variantAttributes,
  ];

  static const _fieldHintsVe = <CatalogImportField, String>{
    CatalogImportField.sku:
        'Código de artículo de tu facturación o ERP (debe ser único por repuesto).',
    CatalogImportField.name:
        'Nombre comercial que verán las tiendas minoristas en el catálogo.',
    CatalogImportField.description:
        'Detalle técnico, referencia OEM o notas del repuesto.',
    CatalogImportField.priceUsd:
        'Precio de lista (en catálogo: REF, o USD si su cuenta es solo divisas).',
    CatalogImportField.salePriceUsd:
        'Precio promocional en USD, si aplica. Debe ser menor al precio de lista.',
        CatalogImportField.stock: '0 si está agotado.',
    CatalogImportField.minOrderQty:
        'Mínimo por pedido. Vacío = ${ProductMinOrderQty.platformDefault}.',
    CatalogImportField.category:
        'Familia o línea (Motor, Frenos, Eléctrico, etc.).',
    CatalogImportField.compatibility:
        'Modelos de moto compatibles (ej. CG150, Bera 150).',
    CatalogImportField.imageUrl: 'Enlace público a la foto del repuesto.',
    CatalogImportField.parentSku:
        'Mismo código en las filas que son variantes de un producto. Vacío = producto simple.',
    CatalogImportField.variantAttributeName:
        'Un solo eje: Presentación, Medida, Color. Si usas varios, deja vacío y usa Atributos.',
    CatalogImportField.variantAttributeValue:
        'Valor de un solo eje: 4 Litros, Rojo. Obligatorio si hay SKU padre y no usas Atributos.',
    CatalogImportField.variantAttributes:
        'Varios ejes en una celda: Tamaño:M|Color:Rojo (o JSON). Cada combinación = una fila/SKU.',
    CatalogImportField.hasWarranty:
        'Usa si/no, o días numéricos del ERP (ej. 30, 90 días).',
    CatalogImportField.isActive:
        'si = visible en catálogo; no = pausado. Vacío: nuevos siguen el selector de la importación; existentes no cambian.',
  };

  String _labelVe(CatalogImportField field) => switch (field) {
        CatalogImportField.sku => 'Código / SKU',
        CatalogImportField.name => 'Nombre del repuesto',
        CatalogImportField.description => 'Descripción',
        CatalogImportField.priceUsd => widget.pagoSoloDivisas
            ? 'Precio de lista (USD)'
            : 'Precio de lista (REF)',
        CatalogImportField.salePriceUsd => 'Precio oferta (USD)',
        CatalogImportField.stock => 'Existencia / stock',
        CatalogImportField.minOrderQty => 'Cantidad mínima de pedido',
        CatalogImportField.category => 'Categoría',
        CatalogImportField.compatibility => 'Compatibilidad',
        CatalogImportField.imageUrl => 'URL de imagen',
        CatalogImportField.parentSku => 'SKU padre',
        CatalogImportField.variantAttributeName => 'Atributo de la variante',
        CatalogImportField.variantAttributeValue => 'Valor de la variante',
        CatalogImportField.variantAttributes => 'Atributos (varios)',
        CatalogImportField.hasWarranty => 'Garantía',
        CatalogImportField.isActive => 'Activo / visible',
        CatalogImportField.usdPaymentDiscountPct => 'Descuento pago en USD (%)',
        CatalogImportField.volumeTiersJson => 'Tramos por volumen (JSON)',
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _readWorkbookImages();
    });
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
        ..._columnSelections.values
            .whereType<String>()
            .where((s) => s.isNotEmpty),
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

  int get _detectedPhotos {
    final embedded = _workbookPhotos?.photos.length ?? 0;
    final zip = _photoZipName == null
        ? 0
        : _photos.where((draft) => draft.workbookPhoto == null).length;
    return embedded + zip;
  }

  int get _includedPhotos => _photos.where((draft) => draft.approved).length;

  String get _importSignature => [
        _columnSelections.entries.map((e) => '${e.key}:${e.value}').join('|'),
        '$_emptyStockFill',
        '$_emptyPriceFill',
        '$_decimalCommaOnPrice',
        _upsertMode.name,
        _newProductsVisibility.name,
        '$_captureUnmapped',
        _corrections.entries
            .map((e) => '${e.key}:${e.value.entries.map((c) => '${c.key}=${c.value}').join(',')}')
            .join(';'),
        '$_includedPhotos',
        '$_detectedPhotos',
      ].join('#');

  CatalogImportSampleScan get _sampleScan => CatalogImportSampleScan.inspect(
        rows: _reviewedSampleRows,
        skuColumn: _columnSelections[CatalogImportField.sku.key],
        nameColumn: _columnSelections[CatalogImportField.name.key],
        priceColumn: _columnSelections[CatalogImportField.priceUsd.key],
        stockColumn: _columnSelections[CatalogImportField.stock.key],
        emptyStockFill: _emptyStockFill,
        emptyPriceFill: _emptyPriceFill,
      );

  List<String> get _missingLabels {
    final labels = <String>[];
    for (final field in catalogImportRequiredFields) {
      if (field == CatalogImportField.stock && _emptyStockFill != null) {
        continue;
      }
      if (field == CatalogImportField.priceUsd && _emptyPriceFill != null) {
        continue;
      }
      if ((_columnSelections[field.key] ?? '').isEmpty) {
        labels.add(_labelVe(field));
      }
    }
    return labels;
  }

  CatalogImportLiveStatus get _liveStatus => CatalogImportLiveStatus.resolve(
        missingLabels: _missingLabels,
        scan: _sampleScan,
        estimatedRows: widget.preview.totalDataRowsEstimate,
        emptyStockFill: _emptyStockFill,
        emptyPriceFill: _emptyPriceFill,
        decimalCommaOn: _decimalCommaOnPrice,
        lastRun: _lastDryRunKey == _importSignature ? _lastDryRun : null,
        detectedPhotos: _detectedPhotos,
        includedPhotos: _includedPhotos,
      );

  void _applyEmptyStock(int value) {
    setState(() => _emptyStockFill = value);
    _showMessage('Stock vacío = $value. El estado de validación ya se actualizó.');
  }

  Future<void> _askFixedStock() async {
    final theme = B2BThemeExtension.of(context);
    final controller = TextEditingController(
      text: _emptyStockFill?.toString() ?? '0',
    );
    final value = await _showAdaptive<int>(
      maxWidth: 420,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Valor fijo de stock',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se usa en las celdas vacías. Las que ya tienen número no cambian.',
              style: TextStyle(color: theme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Existencias',
                filled: true,
                fillColor: theme.inputFill,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final n = int.tryParse(controller.text.trim());
                    Navigator.pop(ctx, n != null && n >= 0 ? n : null);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value != null) _applyEmptyStock(value);
  }

  Future<void> _askFixedPrice() async {
    final theme = B2BThemeExtension.of(context);
    final controller = TextEditingController(
      text: _emptyPriceFill?.toString() ?? '',
    );
    final value = await _showAdaptive<double>(
      maxWidth: 420,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Precio fijo',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Solo rellena precios vacíos.',
              style: TextStyle(color: theme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Precio',
                filled: true,
                fillColor: theme.inputFill,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final n = CatalogImportValidator.parseImportNumber(
                      controller.text,
                    );
                    Navigator.pop(ctx, n != null && n >= 0 ? n : null);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null) return;
    setState(() => _emptyPriceFill = value);
    _showMessage('Precio vacío = $value.');
  }

  Future<void> _remapColumn(CatalogImportField field) async {
    final theme = B2BThemeExtension.of(context);
    final selected = await _showAdaptive<String>(
      maxWidth: 440,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Columna de ${_labelVe(field)}',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final header in widget.preview.headers)
                    ListTile(
                      title: Text(
                        header,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textPrimary),
                      ),
                      onTap: () => Navigator.pop(ctx, header),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _columnSelections[field.key] = selected);
  }

  Widget _quickActions({required bool dense}) {
    final status = _liveStatus;
    final scan = _sampleScan;
    final chips = <Widget>[];
    if (status.stockNeedsAction) {
      chips.addAll([
        ActionChip(
          label: const Text('Asignar 0 a stock vacío'),
          onPressed: _importing ? null : () => _applyEmptyStock(0),
        ),
        ActionChip(
          label: Text('Stock mínimo (${ProductMinOrderQty.platformDefault})'),
          onPressed: _importing
              ? null
              : () => _applyEmptyStock(ProductMinOrderQty.platformDefault),
        ),
        ActionChip(
          label: const Text('Valor fijo'),
          onPressed: _importing ? null : _askFixedStock,
        ),
        ActionChip(
          label: const Text('Mapear otra columna'),
          onPressed: _importing
              ? null
              : () => _remapColumn(CatalogImportField.stock),
        ),
      ]);
    }
    if (status.priceNeedsAction) {
      chips.addAll([
        ActionChip(
          label: const Text('Definir precio fijo'),
          onPressed: _importing ? null : _askFixedPrice,
        ),
        ActionChip(
          label: const Text('Mapear precio'),
          onPressed: _importing
              ? null
              : () => _remapColumn(CatalogImportField.priceUsd),
        ),
      ]);
    }
    if (status.commaNeedsAction) {
      chips.add(
        ActionChip(
          label: Text(
            scan.commaAmbiguous ? 'Hay coma y punto' : 'Usar coma decimal',
          ),
          onPressed: _importing
              ? null
              : () => setState(() => _decimalCommaOnPrice = true),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: dense ? 0 : 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  CatalogImportMapping _buildMapping({required bool dryRun}) {
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
      } else if (field == CatalogImportField.hasWarranty ||
          field == CatalogImportField.isActive) {
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
        dryRun: dryRun,
        newProductsActive: _newProductsVisibility.isActive,
        pagoSoloDivisas: widget.pagoSoloDivisas,
        emptyStockFill: _emptyStockFill,
        emptyPriceFill: _emptyPriceFill,
      ),
      columnMap: columnMap,
      customFieldsMap: _buildCustomFieldsMap(),
      aliadoVisibleCustomFieldKeys: _buildAliadoVisibleCustomFieldKeys(),
      unmappedColumnsPolicy: _captureUnmapped
          ? CatalogUnmappedColumnsPolicy.captureAsCustom
          : CatalogUnmappedColumnsPolicy.ignore,
    );
  }

  void _startProgress(String label) {
    setState(() {
      _importing = true;
      _cancelRequested = false;
      _progressLabel = label;
      _processedRows = 0;
      _lastProgressUiUpdateMs = 0;
      _partial = null;
    });
  }

  bool _validateMapping() {
    final missing = _buildMapping(dryRun: true).missingRequiredFields();
    if (missing.isEmpty) return true;
    _showMessage('Completa el mapeo de: ${missing.join(', ')}');
    return false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<CatalogImportResult> _execute({
    required bool dryRun,
    Map<String, CatalogPhotoTarget>? targets,
    Set<String> photoSkuKeys = const {},
    void Function(String)? onSourceSku,
    void Function(int rowIndex, String sku, String name)? onCatalogRow,
    void Function(String)? onProductSaved,
  }) {
    return CatalogImportOrchestrator.execute(
      bytes: widget.bytes,
      mapping: _buildMapping(dryRun: dryRun),
      corrections: _corrections,
      photoSkuKeys: photoSkuKeys,
      onSourceSku: onSourceSku,
      onCatalogRow: onCatalogRow,
      onProductSaved: onProductSaved,
      onPhotoCandidate: targets == null
          ? null
          : (row, available) {
              targets[row.sku.trim().toLowerCase()] =
                  (row: row, available: available);
            },
      onProgress: (rows, partial) {
        if (!mounted) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastProgressUiUpdateMs < 120 &&
            rows < (widget.preview.totalDataRowsEstimate ?? rows)) {
          return;
        }
        _lastProgressUiUpdateMs = now;
        setState(() {
          _processedRows = rows;
          _partial = partial;
        });
      },
      shouldCancel: () => _cancelRequested,
    );
  }

  Future<void> _readWorkbookImages() async {
    if (widget.fileMeta.format != CatalogImportFileFormat.xlsx) return;
    setState(() => _readingWorkbookPhotos = true);
    CatalogPhotoSource result;
    try {
      result = await compute(readWorkbookPhotos, (
        bytes: widget.bytes,
        sheetName: widget.fileMeta.sheetName,
      ));
    } catch (_) {
      result = (
        sheet: null,
        photos: const [],
        issues: const [
          'No se pudieron leer las fotos incrustadas.',
        ]
      );
    }
    if (!mounted) return;
    setState(() {
      _workbookPhotos = (
        sheet: result.sheet,
        photos: result.photos
            .where((photo) =>
                photo.sourceRow == null ||
                photo.sourceRow! >= widget.fileMeta.dataStartsAtRow)
            .toList(),
        issues: result.issues,
      );
      _readingWorkbookPhotos = false;
    });
  }

  Future<void> _reviewPhotos({required bool chooseZip}) async {
    if (!_validateMapping()) return;
    _startProgress('Preparando las fotos…');
    try {
      final picked = chooseZip
          ? await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['zip'],
              withData: true,
            )
          : null;
      if (!mounted || (chooseZip && picked == null)) return;

      final targets = <String, CatalogPhotoTarget>{};
      final catalog = <String, CatalogSkuChoice>{};
      final sourceSkus = <String>{};
      await _execute(
        dryRun: true,
        targets: targets,
        onSourceSku: sourceSkus.add,
        onCatalogRow: (rowIndex, sku, name) {
          final key = sku.trim().toLowerCase();
          if (key.isEmpty) return;
          final current = catalog[key];
          if (current == null || (current.name.isEmpty && name.trim().isNotEmpty)) {
            catalog[key] = CatalogSkuChoice(
              sku: sku.trim(),
              name: name.trim(),
              rowIndex: rowIndex,
            );
          }
          targets.putIfAbsent(
            key,
            () => (
              row: CatalogImportNormalizedRow(
                rowIndex: rowIndex,
                sku: sku.trim(),
                name: name.trim(),
                priceUsd: 0,
                stock: 0,
              ),
              available: true,
            ),
          );
        },
      );
      if (!mounted) return;

      var drafts = _photos.toList();
      final workbook = _workbookPhotos;
      var zipName = _photoZipName;
      var invalid = _invalidPhotoFiles;
      if (picked != null) {
        final file = picked.files.single;
        final bytes = file.bytes;
        if (bytes == null) {
          throw const FormatException('No se pudo leer el ZIP.');
        }
        final preview = ProductImageBulkService.parseZipBytes(
          bytes,
          knownSkuKeys: sourceSkus,
          keepAmbiguousForReview: true,
        );
        drafts = [
          ...drafts.where((draft) => draft.workbookPhoto != null),
          for (final file in preview.files)
            CatalogPhotoDraft(
              file: file,
              sku: file.sku,
              slot: file.slot,
              approved: targets[file.sku.toLowerCase()]?.available == true,
            ),
        ];
        zipName = file.name;
        invalid = preview.invalidEntries;
      }
      if (!_workbookReviewed && workbook != null) {
        final pdf = widget.fileName.toLowerCase().endsWith('.pdf');
        drafts.addAll(
          CatalogPhotoDraft.fromWorkbook(
            workbook.photos,
            targets,
            existing: drafts,
            sourceRowOffset: widget.sourceRowOffset,
            trustAnchoredRow: pdf,
            approveSuggestions: !pdf,
          ),
        );
      }
      if (picked != null || !_workbookReviewed) {
        final conflicts = CatalogPhotoDraft.assignmentErrors(drafts, targets);
        drafts = [
          for (final draft in drafts)
            conflicts.containsKey(draft.skuKey)
                ? draft.copyWith(approved: false)
                : draft,
        ];
      }

      setState(() => _importing = false);
      final reviewed =
          await Navigator.of(context).push<List<CatalogPhotoDraft>>(
        MaterialPageRoute(
          builder: (_) => CatalogImportPhotoReview(
            drafts: drafts,
            targets: targets,
            catalog: (catalog.values.toList()
              ..sort((a, b) => a.rowIndex.compareTo(b.rowIndex))),
            invalidEntries: [...?workbook?.issues, ...invalid],
          ),
        ),
      );
      if (!mounted || reviewed == null) return;
      setState(() {
        _photos = reviewed;
        _workbookReviewed = workbook != null;
        _photoZipName = zipName;
        _invalidPhotoFiles = invalid;
      });
    } on FormatException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudieron preparar las fotos. Reintenta.');
      }
    } finally {
      if (mounted && _importing) setState(() => _importing = false);
    }
  }

  Widget _buildPhotoSection() {
    final name = _photoZipName;
    final workbook = _workbookPhotos;
    final embedded = workbook?.photos.length ?? 0;
    final hasWorkbookDetails =
        embedded > 0 || (workbook?.issues.isNotEmpty ?? false);
    final canReview = name != null || hasWorkbookDetails;
    final reviewReady = !_importing && !_readingWorkbookPhotos;
    final included = _photos.where((photo) => photo.approved).length;
    return _sectionCard(
      icon: Icons.photo_library_outlined,
      title: 'Fotos del catálogo',
      subtitle: _readingWorkbookPhotos
          ? 'Buscando fotos en el Excel…'
          : embedded > 0 && !_workbookReviewed
              ? '$embedded fotos detectadas · ${workbook?.sheet ?? widget.fileName}'
              : _photos.isNotEmpty
                  ? '$included de ${_photos.length} fotos incluidas'
                  : 'Adjunta un ZIP de fotos para incluirlas en el lote.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (canReview)
            OutlinedButton.icon(
              onPressed:
                  reviewReady ? () => _reviewPhotos(chooseZip: false) : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Revisar fotos'),
            ),
          if (name == null)
            OutlinedButton.icon(
              onPressed:
                  reviewReady ? () => _reviewPhotos(chooseZip: true) : null,
              icon: const Icon(Icons.attach_file),
              label: const Text('Adjuntar ZIP'),
            ),
          if (name != null) ...[
            TextButton(
              onPressed:
                  reviewReady ? () => _reviewPhotos(chooseZip: true) : null,
              child: const Text('Cambiar ZIP'),
            ),
            TextButton(
              onPressed: _importing
                  ? null
                  : () => setState(() {
                        _photos = _photos
                            .where((draft) => draft.workbookPhoto != null)
                            .toList();
                        _invalidPhotoFiles = [];
                        _photoZipName = null;
                      }),
              child: const Text('Quitar ZIP'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runImport() async {
    if (!_validateMapping()) return;
    _startProgress('Simulando filas…');
    var saving = false;
    try {
      final targets = <String, CatalogPhotoTarget>{};
      final result = await _execute(
        dryRun: true,
        targets: _photos.isEmpty ? null : targets,
      );
      if (!mounted) return;
      if (_cancelRequested) {
        setState(() => _importing = false);
        _showMessage('Simulación cancelada. El mapeo se conserva.');
        return;
      }
      setState(() {
        _importing = false;
        _lastDryRun = result;
        _lastDryRunKey = _importSignature;
      });

      final assignmentErrors =
          CatalogPhotoDraft.assignmentErrors(_photos, targets);
      final photos = <String, List<ProductImageBulkFile>>{};
      for (final draft in _photos.where((draft) => draft.approved)) {
        final file = draft.assigned;
        final bytes = catalogMasterNeedsFit(file.bytes)
            ? await compute(fitCatalogMasterBytes, file.bytes)
            : file.bytes;
        photos.putIfAbsent(draft.skuKey, () => []).add(ProductImageBulkFile(
              pathInZip: file.pathInZip,
              bytes: bytes,
              extension: identical(bytes, file.bytes) ? file.extension : 'jpeg',
              sku: file.sku,
              slot: file.slot,
            ));
      }

      final confirmed = await _showSimulation(result, assignmentErrors);
      if (!mounted || confirmed != true) return;

      saving = true;
      _startProgress('Guardando repuestos…');
      final savedSkus = <String>{};
      final imported = await _execute(
        dryRun: false,
        photoSkuKeys: photos.keys.toSet(),
        onProductSaved: savedSkus.add,
      );
      if (!mounted) return;
      if (_cancelRequested) {
        setState(() => _importing = false);
        final retry = await _showImportFailure(
          title: 'Guardado detenido',
          body: 'Se guardaron ${imported.successCount} repuestos antes de '
              'cancelar. El mapeo sigue igual: puedes reintentar el resto.',
        );
        if (retry == true && mounted) return _runImport();
        return;
      }
      final eligiblePhotos = {
        for (final sku in savedSkus) sku: photos[sku]!,
      };
      setState(() {
        _progressLabel = 'Guardando fotos…';
        _savingPhotos = true;
      });
      final savedPhotos = await CatalogPhotoWriteResult.save(eligiblePhotos);
      if (!mounted) return;
      setState(() {
        _importing = false;
        _savingPhotos = false;
      });
      await _showImportOutcome(
        imported,
        savedPhotos,
        eligiblePhotos,
        photos.keys.where((sku) => !savedSkus.contains(sku)).toList(),
      );
      if (mounted) Navigator.pop(context, imported);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _savingPhotos = false;
      });
      final saved = _partial?.successCount ?? 0;
      final retry = await _showImportFailure(
        title: saving ? 'No se completó el guardado' : 'No se pudo simular',
        body: saving
            ? 'Falló el lote después de guardar $saved repuestos. '
                'El mapeo se conserva: reintenta sin volver a asociar columnas.'
            : 'No se pudo leer el archivo para simular. '
                'El mapeo se conserva. ${_readableError(error)}',
      );
      if (retry == true && mounted) return _runImport();
    } finally {
      if (mounted && _importing) setState(() => _importing = false);
    }
  }

  String _readableError(Object error) {
    if (error is FormatException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return 'Inténtalo de nuevo.';
  }

  String _formatImportError(CatalogImportRowError error) {
    final sku = error.sku?.trim();
    final code = sku == null || sku.isEmpty ? '' : ' · $sku';
    return 'Fila ${error.rowIndex + widget.sourceRowOffset}$code · ${error.message}';
  }

  Future<void> _downloadReviewedWorkbook() async {
    try {
      final bytes = await FlexibleCatalogImportService.buildReviewedWorkbook(
        bytes: widget.bytes,
        mapping: _buildMapping(dryRun: true),
        corrections: _corrections,
      );
      if (!mounted) return;
      final result = await saveExcelForExport(
        name: 'b2bconecta_inventario_revisado',
        bytes: bytes,
      );
      if (mounted && result != ExcelExportResult.cancelled) {
        _showMessage(
            excelExportSavedMessage('Inventario revisado descargado.'));
      }
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('No se pudo descargar el inventario revisado.');
    }
  }

  Future<bool?> _showSimulation(
    CatalogImportResult result,
    Map<String, String> assignmentErrors,
  ) {
    final isPdf = widget.fileName.toLowerCase().endsWith('.pdf');
    final embedded = _workbookPhotos?.photos.length ?? 0;
    return _showAdaptive<bool>(
      expand: true,
      maxWidth: 920,
      builder: (ctx) => ImporterImportReviewPanel(
        result: result,
        detectedPhotos: _detectedPhotos,
        includedPhotos: _includedPhotos,
        discardedFiles: _invalidPhotoFiles.length,
        workbookPending: !_workbookReviewed && embedded > 0,
        assignmentErrors: assignmentErrors,
        requirePdfConfirm: widget.documentPhotos != null && isPdf,
        formatError: _formatImportError,
        onEditRow: (error) async {
          await _correctRow(error.rowIndex, message: error.message);
          if (ctx.mounted) Navigator.pop(ctx, false);
        },
        onFillEmptyStock: (value) {
          setState(() => _emptyStockFill = value);
          Navigator.pop(ctx, false);
          _showMessage(
            'Stock vacío = $value. Vuelve a simular para actualizar los errores.',
          );
        },
        onDownload: result.errorCount == 0 && result.successCount > 0
            ? _downloadReviewedWorkbook
            : null,
        onBack: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
  }

  Future<T?> _showAdaptive<T>({
    required WidgetBuilder builder,
    double maxWidth = 560,
    bool expand = false,
  }) {
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
    final theme = B2BThemeExtension.of(context);
    if (!wide) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: theme.dialogSurface,
        builder: (ctx) {
          final height = MediaQuery.sizeOf(ctx).height * (expand ? 0.92 : 0.72);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: SizedBox(
              height: expand ? height : null,
              child: SafeArea(child: builder(ctx)),
            ),
          );
        },
      );
    }
    return showDialog<T>(
      context: context,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * (expand ? 0.86 : 0.7);
        return Dialog(
          backgroundColor: theme.dialogSurface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: height,
            ),
            child: SizedBox(
              width: maxWidth,
              height: expand ? height : null,
              child: builder(ctx),
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showImportFailure({
    required String title,
    required String body,
  }) {
    final theme = B2BThemeExtension.of(context);
    return _showAdaptive<bool>(
      maxWidth: 480,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(color: theme.textSecondary, height: 1.4)),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cerrar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>?> _correctRow(
    int rowIndex, {
    String? message,
    Map<String, String>? originalValues,
  }) async {
    final mapping = _buildMapping(dryRun: true);
    final original = originalValues ??
        FlexibleCatalogImportService.readRows(
          bytes: widget.bytes,
          meta: widget.fileMeta,
          rowNumbers: {rowIndex},
        )[rowIndex];
    if (original == null) return null;

    final fields = <String, String>{};
    for (final field in CatalogImportField.values) {
      final source = mapping.columnMap[field.key]?.source;
      if (source != null) fields.putIfAbsent(source, () => field.label);
    }
    if (originalValues != null) {
      for (final header in original.keys) {
        fields.putIfAbsent(header, () => header);
      }
    }
    final values = {...original, ...?_corrections[rowIndex]};
    final edited = <String, String>{};
    final theme = B2BThemeExtension.of(context);
    final saved = await _showAdaptive<bool>(
      expand: true,
      maxWidth: 560,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Fila ${rowIndex + widget.sourceRowOffset}',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (message != null) ...[
                  Text(message, style: TextStyle(color: theme.textSecondary)),
                  const SizedBox(height: 12),
                ],
                for (final source in fields.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      initialValue: values[source],
                      decoration: InputDecoration(
                        labelText: fields[source],
                        filled: true,
                        fillColor: theme.inputFill,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => edited[source] = value,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted || saved != true || edited.isEmpty) return null;
    setState(() => _corrections.putIfAbsent(rowIndex, () => {}).addAll(edited));
    if (originalValues == null) {
      _showMessage(
          'Fila ${rowIndex + widget.sourceRowOffset} corregida. Vuelve a simular.');
    }
    return edited;
  }

  Future<void> _showImportOutcome(
    CatalogImportResult products,
    CatalogPhotoWriteResult initial,
    Map<String, List<ProductImageBulkFile>> eligiblePhotos,
    List<String> excluded,
  ) async {
    var photos = initial;
    var saved = initial.saved;
    var skipped = initial.skipped;
    final pageContext = context;
    while (true) {
      if (!pageContext.mounted) return;
      final theme = B2BThemeExtension.of(pageContext);
      final mobile = MediaQuery.sizeOf(pageContext).width <
          AppBreakpoints.mobileMenu;
      final notes = <String>[
        if (products.inserted > 0 && !_newProductsVisibility.isActive)
          'Los repuestos nuevos quedan en pausa.',
        for (final error in products.allErrors.take(20))
          _formatImportError(error),
        if (eligiblePhotos.isNotEmpty || excluded.isNotEmpty) ...[
          'Galerías guardadas: $saved',
          if (skipped > 0) 'Galerías con fotos existentes: $skipped',
          if (excluded.isNotEmpty)
            'Sin confirmación del repuesto: ${excluded.take(20).join(', ')}',
          for (final item in photos.pending.entries.take(20))
            '${item.key} · ${item.value}',
          if (photos.pending.length > 20)
            '${photos.pending.length} galerías pendientes en total.',
        ],
      ];
      Widget card(BuildContext ctx) {
        return _ImportOutcomeCard(
          inserted: products.inserted,
          updated: products.updated,
          skippedRows: products.skipped,
          errors: products.errorCount,
          notes: notes,
          canRetryPhotos: photos.pending.isNotEmpty,
          onClose: () => Navigator.pop(ctx, false),
          onRetry: photos.pending.isEmpty
              ? null
              : () => Navigator.pop(ctx, true),
        );
      }

      final bool? retry;
      if (mobile) {
        retry = await showModalBottomSheet<bool>(
          context: pageContext,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: theme.dialogSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: card(ctx),
          ),
        );
      } else {
        retry = await showDialog<bool>(
          context: pageContext,
          barrierDismissible: false,
          barrierColor: theme.textPrimary.withOpacity(0.35),
          builder: (ctx) => Dialog(
            backgroundColor: theme.dialogSurface,
            surfaceTintColor: theme.dialogSurface,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.borderSubtle),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: card(ctx),
            ),
          ),
        );
      }
      if (!pageContext.mounted || retry != true) return;
      _startProgress('Reintentando fotos…');
      setState(() => _savingPhotos = true);
      photos = await CatalogPhotoWriteResult.save({
        for (final sku in photos.pending.keys) sku: eligiblePhotos[sku]!,
      });
      saved += photos.saved;
      skipped += photos.skipped;
      if (mounted) {
        setState(() {
          _importing = false;
          _savingPhotos = false;
        });
      }
    }
  }

  static String _upsertModeLabel(
    CatalogImportUpsertMode mode, {
    bool compact = false,
  }) =>
      switch (mode) {
        CatalogImportUpsertMode.updateAll => compact
            ? 'Actualizar todo'
            : 'Actualizar nombre, precio, stock y demás campos',
        CatalogImportUpsertMode.priceStockOnly =>
          compact ? 'Solo precio y stock' : 'Actualizar precios y existencias',
        CatalogImportUpsertMode.insertOnly => compact
            ? 'Solo códigos nuevos'
            : 'No tocar existentes; solo cargar códigos nuevos',
      };

  static String _upsertModeDescription(CatalogImportUpsertMode mode) =>
      switch (mode) {
        CatalogImportUpsertMode.updateAll =>
          'Actualiza nombre, precios, existencias y otros datos del catálogo.',
        CatalogImportUpsertMode.priceStockOnly =>
          'Actualiza precios y existencias. Revisa también la oferta, la garantía y los campos opcionales del archivo.',
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
    final theme = B2BThemeExtension.of(context);
    return Card(
      elevation: 0,
      color: theme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppDecorations.radius12,
        side: BorderSide(color: theme.borderSubtle),
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
                  Icon(icon, size: 20, color: theme.brand),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: theme.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.textSecondary,
                            height: 1.35,
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
    final ext = widget.fileName.split('.').last.toUpperCase();
    final theme = B2BThemeExtension.of(context);

    return _sectionCard(
      icon: Icons.description_outlined,
      title: widget.fileName,
      subtitle: '$ext · ${widget.preview.headers.length} columnas · '
          '${estimate ?? '?'} filas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SKU, nombre, precio y stock.',
            style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
          ),
          if (widget.documentPhotos != null)
            for (final issue in widget.documentPhotos!.issues.take(4))
              Text(
                issue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
          _previewDetailsButton(),
        ],
      ),
    );
  }

  Widget _autoMapReadyBanner() {
    final status = _liveStatus;
    if (!status.clean) return const SizedBox.shrink();
    final theme = B2BThemeExtension.of(context);
    final tone = status.clean ? theme.successFg : theme.warningFg;
    final bg = status.clean ? theme.successBg : theme.warningBg;
    final detail = status.clean
        ? (_captureUnmapped && _unmappedHeaders().isNotEmpty
            ? 'Columnas listas · ${_unmappedHeaders().length} extra'
            : 'Columnas listas.')
        : status.message;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: tone.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status.clean ? Icons.check_circle : Icons.error_outline,
            color: tone,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              detail,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: theme.textPrimary,
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
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.surfaceCard,
      elevation: 0,
      borderRadius: AppDecorations.radius12,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppDecorations.radius12,
          border: Border.all(color: theme.borderSubtle),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: expanded,
            onExpansionChanged: onExpandedChanged,
            tilePadding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: Icon(icon, color: theme.brand, size: 22),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: theme.textPrimary,
              ),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.3, color: theme.textSecondary),
            ),
            children: [child],
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator({required bool desktop}) {
    final theme = B2BThemeExtension.of(context);
    final mapped = _missingLabels.isEmpty;
    final clean = _liveStatus.clean;
    final step2Count = _customFieldMappings
        .where(
            (r) => (r.fieldLabel.trim().isNotEmpty) && r.sourceColumn != null)
        .length;
    final autoCount = _captureUnmapped ? _unmappedHeaders().length : 0;

    Widget step(int n, String label, String detail, bool done) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: done ? theme.brandContainer : theme.inputFill,
            borderRadius: AppDecorations.radius12,
            border: Border.all(
              color: done ? theme.brand.withOpacity(0.35) : theme.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: done ? theme.brand : theme.textMuted,
                child: Text(
                  '$n',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: desktop ? 13 : 12,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondary,
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
          '$_mappedRequiredCount/${catalogImportRequiredFields.length}',
          mapped,
        ),
        const SizedBox(width: 8),
        step(
          2,
          'Extras',
          step2Count > 0
              ? '$step2Count'
              : autoCount > 0
                  ? '$autoCount auto'
                  : 'Opcional',
          step2Count > 0 || (_captureUnmapped && autoCount > 0),
        ),
        const SizedBox(width: 8),
        step(3, 'Confirmar', clean ? 'Listo' : 'Revisar', clean),
      ],
    );
  }

  Widget _coreMappingCard({required bool desktop}) {
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
      subtitle: 'SKU, nombre, precio y stock.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Obligatorios',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          requiredGrid(),
        ],
      ),
    );
  }

  Widget _optionalFieldsSection({required bool desktop}) {
    final fields = _optionalFields.where((f) {
      if (!widget.pagoSoloDivisas) return true;
      return f != CatalogImportField.usdPaymentDiscountPct &&
          f != CatalogImportField.salePriceUsd;
    }).toList();
    final mapped = fields
        .where((f) => (_columnSelections[f.key] ?? '').trim().isNotEmpty)
        .length;

    return _sectionCard(
      icon: Icons.list_alt_outlined,
      title: 'Campos opcionales',
      subtitle: mapped == 0
          ? 'Listado compacto. Vacío = no se importa.'
          : '$mapped de ${fields.length} con columna.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoCol = desktop && constraints.maxWidth >= 640;
          final itemWidth =
              twoCol ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 0,
            children: [
              for (final field in fields)
                SizedBox(
                  width: itemWidth,
                  child: _fieldDropdown(field, compact: true),
                ),
            ],
          );
        },
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
          : 'Marca, ubicación, código de barras… Usa el ojo para visibilidad tienda minorista.',
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
                label: const Text('Ocultar todos para tiendas minoristas'),
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
                label: const Text('Mostrar todos a tiendas minoristas'),
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
                      ? 'Visible para tiendas minoristas (tocar para ocultar)'
                      : 'Solo interno (tocar para mostrar a tiendas minoristas)',
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
              onPressed: _importing ? null : () => _addErpFieldFromColumn(h),
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
        final threeCol = constraints.maxWidth >= 640;
        final tileWidth =
            threeCol ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;

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
                                : B2BThemeExtension.of(context).inputFill,
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
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
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
        title: 'Coma decimal',
        subtitle: 'Precios como 12,50.',
        value: _decimalCommaOnPrice,
        onChanged:
            _importing ? null : (v) => setState(() => _decimalCommaOnPrice = v),
      ),
      _ImportOptionTileData(
        icon: Icons.library_add_outlined,
        title: 'Guardar columnas extra',
        subtitle: 'Las no mapeadas se guardan con su nombre.',
        value: _captureUnmapped,
        onChanged:
            _importing ? null : (v) => setState(() => _captureUnmapped = v),
      ),
    ];

    final rules = _sectionCard(
      icon: Icons.sync,
      title: 'Códigos ya registrados',
      subtitle: 'Si el SKU ya está en tu inventario.',
      child: desktop
          ? _upsertModeCards()
          : _upsertModeDropdown(compact: true),
    );
    final visibility = _sectionCard(
      icon: Icons.visibility_outlined,
      title: 'Productos nuevos',
      subtitle: _newProductsVisibility == ImporterNewProductsVisibility.paused
          ? 'Entran en pausa hasta que los publiques.'
          : 'Entran visibles en el catálogo.',
      child: ImporterNewProductsVisibilitySection(
        value: _newProductsVisibility,
        enabled: !_importing,
        compact: !desktop,
        horizontal: desktop,
        onChanged: (v) => setState(() => _newProductsVisibility = v),
      ),
    );
    final advanced = _sectionCard(
      icon: Icons.tune,
      title: 'Opciones avanzadas',
      subtitle: 'Separador decimal y columnas extra.',
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < optionTiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _ImportOptionTile(data: optionTiles[i])),
                ],
              ],
            )
          : Column(
              children: [
                for (final tile in optionTiles) _ImportOptionTile(data: tile),
              ],
            ),
    );

    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          rules,
          const SizedBox(height: 12),
          visibility,
          const SizedBox(height: 12),
          advanced,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rules,
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: visibility),
            const SizedBox(width: 12),
            Expanded(child: advanced),
          ],
        ),
      ],
    );
  }

  Future<void> _openPreviewDetails() async {
    // El wizard solo guarda 5 filas de muestra; al abrir detalles releemos
    // el archivo para mostrar todas las filas (hasta el tope de seguridad).
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text(
                  'Cargando filas del archivo…',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    CatalogImportPreview detailsPreview;
    try {
      detailsPreview = await Future<CatalogImportPreview>(() {
        return FlexibleCatalogImportService.previewFile(
          bytes: widget.bytes,
          meta: widget.fileMeta,
          sampleRowCount: FlexibleCatalogImportService.detailsPreviewMaxRows,
          corrections: _corrections,
        );
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo leer el archivo: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    await showCatalogImportPreviewDetailsDialog(
      context: context,
      preview: detailsPreview,
      fileName: widget.fileName,
      coreHeaders: _coreMappedSources,
      erpHeaders: _erpMappedSources,
      rowOffset: widget.sourceRowOffset,
      onEditRow: widget.documentPhotos == null
          ? null
          : (row, values) => _correctRow(row, originalValues: values),
    );
  }

  List<Map<String, String>> get _reviewedSampleRows {
    final rows = widget.preview.sampleRows;
    final numbers = widget.preview.sampleRowNumbers;
    if (_corrections.isEmpty || numbers.length != rows.length) return rows;
    return [
      for (var i = 0; i < rows.length; i++)
        {...rows[i], ...?_corrections[numbers[i]]},
    ];
  }

  Widget _previewDetailsButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('import-preview-details'),
        onPressed: widget.preview.headers.isEmpty ? null : _openPreviewDetails,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          visualDensity: VisualDensity.compact,
          foregroundColor: AppColors.brandBlue,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: const Icon(Icons.open_in_full_rounded, size: 18),
        label: const Text('Ver detalles de la carga'),
      ),
    );
  }

  Widget _previewPanel({required bool matchMapping}) {
    final estimate = widget.preview.totalDataRowsEstimate;
    final rows = matchMapping
        ? _reviewedSampleRows.take(_previewRowLimit).toList()
        : _reviewedSampleRows
            .take(catalogMappingPreviewInitialRows)
            .toList();
    final total = estimate ?? widget.preview.sampleRows.length;
    return _sectionCard(
      icon: Icons.table_chart_outlined,
      title: 'Vista previa',
      subtitle: 'Muestra ${rows.length} de ~$total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _previewDetailsButton(),
          const SizedBox(height: 6),
          _PreviewTable(
            headers: widget.preview.headers,
            rows: rows,
            coreHeaders: _coreMappedSources,
            erpHeaders: _erpMappedSources,
            maxHeight: matchMapping
                ? _previewTableHeight
                : catalogMappingPreviewInitialHeight,
          ),
        ],
      ),
    );
  }

  void _syncPreviewHeight() {
    if (!mounted) return;
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
    if (!desktop) {
      _applyPreviewSize(
        catalogMappingPreviewInitialRows,
        catalogMappingPreviewInitialHeight,
      );
      return;
    }
    final mapping =
        _mappingCardKey.currentContext?.findRenderObject() as RenderBox?;
    final preview =
        _previewCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (mapping == null ||
        preview == null ||
        !mapping.hasSize ||
        !preview.hasSize) {
      return;
    }
    final fit = catalogMappingPreviewFit(
      mappingHeight: mapping.size.height,
      previewHeight: preview.size.height,
      tableHeight: _previewTableHeight,
      sampleCount: widget.preview.sampleRows.length,
    );
    _applyPreviewSize(fit.rows, fit.height);
  }

  void _applyPreviewSize(int rows, double height) {
    if (_previewRowLimit == rows &&
        (_previewTableHeight - height).abs() < 0.5) {
      return;
    }
    setState(() {
      _previewRowLimit = rows;
      _previewTableHeight = height;
    });
  }

  Widget _actionBar({required bool desktop}) {
    final theme = B2BThemeExtension.of(context);
    final status = _liveStatus;
    final tone = status.clean ? theme.successFg : theme.warningFg;
    final importButton = FilledButton.icon(
      onPressed: _importing || _readingWorkbookPhotos || !status.readyToSimulate
          ? null
          : _runImport,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
      icon: const Icon(Icons.fact_check_outlined),
      label: const Text('Simular importación'),
    );
    final statusRow = Row(
      children: [
        Icon(
          status.clean ? Icons.check_circle : Icons.error_outline,
          color: tone,
          size: desktop ? 20 : 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            status.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: desktop ? 13 : 12,
              color: theme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (desktop) ...[
          const SizedBox(width: 12),
          importButton,
        ],
      ],
    );

    return Material(
      color: theme.surfaceCard,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          desktop ? 24 : 16,
          12,
          desktop ? 24 : 16,
          desktop ? 14 : 12,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.borderSubtle)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  statusRow,
                  if (status.stockNeedsAction ||
                      status.priceNeedsAction ||
                      status.commaNeedsAction) ...[
                    const SizedBox(height: 8),
                    _quickActions(dense: true),
                  ],
                  if (!desktop) ...[
                    const SizedBox(height: 10),
                    importButton,
                  ],
                ],
              ),
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
                    _buildPhotoSection(),
                    const SizedBox(height: 14),
                    if (desktop) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 10,
                            child: KeyedSubtree(
                              key: _mappingCardKey,
                              child: _coreMappingCard(desktop: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 11,
                            child: KeyedSubtree(
                              key: _previewCardKey,
                              child: _previewPanel(matchMapping: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _optionalFieldsSection(desktop: true),
                      const SizedBox(height: 14),
                      _customFieldsMappingCard(desktop: true),
                      const SizedBox(height: 14),
                      _optionsCard(desktop: true),
                    ] else ...[
                      _coreMappingCard(desktop: false),
                      const SizedBox(height: 14),
                      _optionalFieldsSection(desktop: false),
                      const SizedBox(height: 14),
                      _optionsCard(desktop: false),
                      const SizedBox(height: 14),
                      _collapsiblePanel(
                        title: 'Vista previa',
                        subtitle: 'Muestra de las filas',
                        icon: Icons.table_chart_outlined,
                        expanded: _previewExpanded,
                        onExpandedChanged: (v) =>
                            setState(() => _previewExpanded = v),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _previewDetailsButton(),
                            const SizedBox(height: 8),
                            _PreviewTable(
                              headers: widget.preview.headers,
                              rows: _reviewedSampleRows
                                  .take(catalogMappingPreviewInitialRows)
                                  .toList(),
                              coreHeaders: _coreMappedSources,
                              erpHeaders: _erpMappedSources,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _customFieldsMappingCard(desktop: false),
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
    final theme = B2BThemeExtension.of(context);
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;

    if (desktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPreviewHeight());
    }

    return PopScope(
      canPop: !_importing,
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.surfaceCard,
          surfaceTintColor: Colors.transparent,
          foregroundColor: theme.textPrimary,
          title: const Text('Carga masiva'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Mapea columnas y revisa antes de guardar',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textSecondary,
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
      ),
    );
  }

  Widget _buildProgressOverlay() {
    final theme = B2BThemeExtension.of(context);
    final partial = _partial;
    final estimate = widget.preview.totalDataRowsEstimate;

    return ColoredBox(
      color: theme.textPrimary.withOpacity(0.35),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: theme.dialogSurface,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: theme.brand),
                  const SizedBox(height: 20),
                  Text(
                    _progressLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: theme.textPrimary,
                    ),
                  ),
                  if (!_savingPhotos) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$_processedRows de ${estimate ?? '?'} filas',
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  ],
                  if (partial != null && !_savingPhotos) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${partial.inserted} nuevos · ${partial.updated} actualizados · ${partial.errorCount} errores',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textPrimary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _cancelRequested = true),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
              color: B2BThemeExtension.of(context).inputFill,
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

const catalogMappingPreviewInitialRows = 5;
const catalogMappingPreviewInitialHeight = 220.0;
const catalogMappingPreviewHeaderHeight = 40.0;
const catalogMappingPreviewRowHeight = 36.0;

/// Altura de la vista previa para igualar «Asocia tus columnas».
///
/// Muestra hasta 7 filas si caben en esa tarjeta. Si una fila más la haría
/// más alta, se queda en 5 filas y 220 px.
@visibleForTesting
({int rows, double height}) catalogMappingPreviewFit({
  required double mappingHeight,
  required double previewHeight,
  required double tableHeight,
  required int sampleCount,
}) {
  const maxRows = 7;
  const gutter = 14.0;
  final chrome = previewHeight - tableHeight;
  if (chrome <= 0 || sampleCount <= catalogMappingPreviewInitialRows) {
    return (
      rows: catalogMappingPreviewInitialRows,
      height: catalogMappingPreviewInitialHeight,
    );
  }
  final available = mappingHeight - chrome;
  if (available <= catalogMappingPreviewInitialHeight + 1) {
    return (
      rows: catalogMappingPreviewInitialRows,
      height: catalogMappingPreviewInitialHeight,
    );
  }
  final fit = ((available -
              catalogMappingPreviewHeaderHeight -
              gutter) /
          catalogMappingPreviewRowHeight)
      .floor();
  if (fit <= catalogMappingPreviewInitialRows) {
    return (
      rows: catalogMappingPreviewInitialRows,
      height: catalogMappingPreviewInitialHeight,
    );
  }
  var shown = fit;
  if (shown > maxRows) shown = maxRows;
  if (shown > sampleCount) shown = sampleCount;
  return (rows: shown, height: available);
}

class _ImportOutcomeCard extends StatelessWidget {
  const _ImportOutcomeCard({
    required this.inserted,
    required this.updated,
    required this.skippedRows,
    required this.errors,
    required this.notes,
    required this.canRetryPhotos,
    required this.onClose,
    required this.onRetry,
  });

  final int inserted;
  final int updated;
  final int skippedRows;
  final int errors;
  final List<String> notes;
  final bool canRetryPhotos;
  final VoidCallback onClose;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final clean = errors == 0 && !canRetryPhotos;
    final tone = clean ? theme.successFg : theme.warningFg;
    final toneBg = clean ? theme.successBg : theme.warningBg;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: toneBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    clean ? Icons.check_rounded : Icons.error_outline,
                    color: tone,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resultado de la importación',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clean
                          ? 'El catálogo quedó actualizado.'
                          : 'Revisa las filas con incidencia.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _metric(theme, 'Creados', inserted)),
              const SizedBox(width: 8),
              Expanded(child: _metric(theme, 'Actualizados', updated)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _metric(theme, 'Omitidas', skippedRows)),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  theme,
                  'Errores',
                  errors,
                  alert: errors > 0,
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _outcomeNotes(theme, notes),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  foregroundColor: theme.textSecondary,
                  minimumSize: const Size(88, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: theme.borderSubtle),
                  ),
                ),
                child: const Text('Cerrar'),
              ),
              if (onRetry != null)
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Reintentar fotos'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outcomeNotes(B2BThemeExtension theme, List<String> notes) {
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
    if (notes.length <= 4) return lines;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 168),
      child: SingleChildScrollView(child: lines),
    );
  }

  Widget _metric(
    B2BThemeExtension theme,
    String label,
    int value, {
    bool alert = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: alert ? theme.warningBg : theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: alert ? theme.warningFg : theme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTable extends StatefulWidget {
  const _PreviewTable({
    required this.headers,
    required this.rows,
    required this.coreHeaders,
    required this.erpHeaders,
    this.maxHeight = catalogMappingPreviewInitialHeight,
  });

  final List<String> headers;
  final List<Map<String, String>> rows;
  final Set<String> coreHeaders;
  final Set<String> erpHeaders;
  final double maxHeight;

  @override
  State<_PreviewTable> createState() => _PreviewTableState();
}

class _PreviewTableState extends State<_PreviewTable> {
  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  Color _headerColor(String h) {
    if (widget.coreHeaders.contains(h)) return AppColors.brandBlue;
    if (widget.erpHeaders.contains(h)) return AppColors.brandAccent;
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.headers.isEmpty) {
      return const Text('No se detectaron columnas en el archivo.');
    }

    final table = DataTable(
      headingRowColor: WidgetStateProperty.all(
        AppColors.brandBlueContainer.withOpacity(0.4),
      ),
      headingRowHeight: catalogMappingPreviewHeaderHeight,
      dataRowMinHeight: catalogMappingPreviewRowHeight,
      dataRowMaxHeight: catalogMappingPreviewRowHeight,
      columnSpacing: 20,
      columns: widget.headers.map((h) {
        final isCore = widget.coreHeaders.contains(h);
        final isErp = widget.erpHeaders.contains(h);
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
      rows: widget.rows
          .map(
            (row) => DataRow(
              cells: widget.headers
                  .map(
                    (h) => DataCell(
                      Text(
                        row[h] ?? '',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.coreHeaders.contains(h) ||
                                  widget.erpHeaders.contains(h)
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
    );

    return ClipRRect(
      borderRadius: AppDecorations.radius12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: B2BThemeExtension.of(context).borderSubtle),
          borderRadius: AppDecorations.radius12,
        ),
        child: SizedBox(
          height: widget.maxHeight,
          child: Scrollbar(
            controller: _horizontalScroll,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: Scrollbar(
                controller: _verticalScroll,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScroll,
                  child: table,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
