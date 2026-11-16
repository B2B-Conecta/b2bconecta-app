import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'catalog_import/catalog_import_field.dart';
import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'catalog_import_orchestrator.dart';
import 'catalog_import_photo_review.dart';
import 'catalog_import_photos.dart';
import 'catalog_photo_source.dart';
import 'catalog_workbook_photos.dart';
import 'product_image_bulk_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/excel_file_export.dart';
import 'catalog_import_header_guess.dart';
import 'catalog_import_preview_details_dialog.dart';
import 'flexible_catalog_import_service.dart';
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
  bool _confirmedExtractedData = false;
  bool _readingWorkbookPhotos = false;
  String? _photoZipName;
  bool _captureUnmapped = true;
  bool _decimalCommaOnPrice = false;
  ImporterNewProductsVisibility _newProductsVisibility =
      ImporterNewProductsVisibility.paused;
  bool _importing = false;
  bool _savingPhotos = false;
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
    CatalogImportField.stock:
        'Unidades en almacén. Asocia «Cantidad» solo si representa existencias. Escribe 0 si el repuesto está agotado.',
    CatalogImportField.minOrderQty:
        'Unidades mínimas por pedido. Si el proveedor la define, esa cantidad manda (mínimo 1). Si no mapeas la columna, los productos nuevos quedan en 5.',
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
    void Function(String)? onProductSaved,
  }) {
    return CatalogImportOrchestrator.execute(
      bytes: widget.bytes,
      mapping: _buildMapping(dryRun: dryRun),
      corrections: _corrections,
      photoSkuKeys: photoSkuKeys,
      onSourceSku: onSourceSku,
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
      final sourceSkus = <String>{};
      await _execute(
        dryRun: true,
        targets: targets,
        onSourceSku: sourceSkus.add,
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
        drafts.addAll(
          CatalogPhotoDraft.fromWorkbook(
            workbook.photos,
            targets,
            existing: drafts,
            sourceRowOffset: widget.sourceRowOffset,
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
            invalidEntries: [...?workbook?.issues, ...invalid],
            originLabel: widget.fileName.toLowerCase().endsWith('.pdf')
                ? 'PDF'
                : 'Excel',
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
    _startProgress('Revisando archivo…');
    try {
      final targets = <String, CatalogPhotoTarget>{};
      final result = await _execute(
        dryRun: true,
        targets: _photos.isEmpty ? null : targets,
      );
      if (!mounted) return;
      setState(() => _importing = false);

      final assignmentErrors =
          CatalogPhotoDraft.assignmentErrors(_photos, targets);
      final photos = <String, List<ProductImageBulkFile>>{};
      for (final draft in _photos.where((draft) => draft.approved)) {
        photos.putIfAbsent(draft.skuKey, () => []).add(draft.assigned);
      }

      _confirmedExtractedData = false;
      final confirmed = await _showSimulation(result, photos, assignmentErrors);
      if (!mounted || confirmed != true) return;

      _startProgress('Guardando repuestos…');
      final savedSkus = <String>{};
      final imported = await _execute(
        dryRun: false,
        photoSkuKeys: photos.keys.toSet(),
        onProductSaved: savedSkus.add,
      );
      if (!mounted) return;
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
    } catch (_) {
      if (mounted) _showMessage('No se pudo completar la importación.');
    } finally {
      if (mounted && _importing) setState(() => _importing = false);
    }
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
    Map<String, List<ProductImageBulkFile>> photos,
    Map<String, String> assignmentErrors,
  ) {
    final included =
        photos.values.fold(0, (total, files) => total + files.length);
    final isPdf = widget.fileName.toLowerCase().endsWith('.pdf');
    var downloading = false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, updateDialog) => AlertDialog(
          title: const Text('Revisa antes de guardar'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${result.inserted} por crear · ${result.updated} por actualizar'),
                Text(
                    '${result.skipped} filas omitidas · ${result.errorCount} con errores'),
                Text('${result.priceChanges} cambios de precio · '
                    '${result.stockChanges} cambios de stock'),
                if (result.imageUrlChanges > 0)
                  Text('${result.imageUrlChanges} cambios de URL de foto'),
                if (_photoZipName != null ||
                    (_workbookPhotos?.photos.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 12),
                  Text(
                      'Fotos incluidas: $included · Repuestos con fotos: ${photos.length}'),
                  Text('${_photos.length - included} fotos sin incluir'
                      '${_invalidPhotoFiles.isEmpty ? '' : ' · ${_invalidPhotoFiles.length} archivos descartados'}'),
                  const Text('Las galerías con fotos se conservan.'),
                  if (!_workbookReviewed &&
                      (_workbookPhotos?.photos.isNotEmpty ?? false))
                    const Text(
                        'Las fotos detectadas se incluyen después de revisarlas.'),
                  if (assignmentErrors.isNotEmpty)
                    Text(
                      'Vuelve a revisar ${assignmentErrors.length} asignaciones de fotos.',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                ],
                if (widget.documentPhotos != null && isPdf)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                        'Revisé el SKU, el precio y el stock extraídos del PDF.'),
                    value: _confirmedExtractedData,
                    onChanged: (value) => updateDialog(
                        () => _confirmedExtractedData = value ?? false),
                  ),
                if (result.validationErrors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Corrige las filas o guarda solo las válidas.'),
                  for (final error in result.validationErrors.take(20))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(_formatImportError(error)),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () async {
                        await _correctRow(error.rowIndex,
                            message: error.message);
                        if (ctx.mounted) Navigator.pop(ctx, false);
                      },
                    ),
                  if (result.validationErrors.length > 20)
                    const Text('Se muestran los primeros 20 errores.'),
                ],
                if (result.validationErrors.isEmpty && result.successCount > 0)
                  TextButton.icon(
                    onPressed:
                        downloading || (isPdf && !_confirmedExtractedData)
                            ? null
                            : () async {
                                updateDialog(() => downloading = true);
                                await _downloadReviewedWorkbook();
                                if (ctx.mounted)
                                  updateDialog(() => downloading = false);
                              },
                    icon: const Icon(Icons.download_outlined),
                    label: Text(downloading
                        ? 'Preparando Excel…'
                        : 'Descargar Excel revisado'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: result.successCount == 0 ||
                      assignmentErrors.isNotEmpty ||
                      (isPdf && !_confirmedExtractedData)
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Confirmar importación'),
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Corregir fila ${rowIndex + widget.sourceRowOffset}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: 12),
              ],
              for (final source in fields.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    initialValue: values[source],
                    decoration: InputDecoration(
                      labelText: fields[source],
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => edited[source] = value,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aplicar corrección'),
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
      final retry = await showDialog<bool>(
        context: pageContext,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Resultado de la importación'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${products.inserted} repuestos creados · ${products.updated} actualizados'),
                Text(
                    '${products.skipped} filas omitidas · ${products.errorCount} errores'),
                if (products.inserted > 0 && !_newProductsVisibility.isActive)
                  const Text('Los repuestos nuevos quedan en pausa.'),
                for (final error in products.allErrors.take(20))
                  Text(_formatImportError(error)),
                if (eligiblePhotos.isNotEmpty || excluded.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Galerías guardadas: $saved'),
                  if (skipped > 0)
                    Text('Galerías con fotos existentes: $skipped'),
                  if (excluded.isNotEmpty)
                    Text(
                        'Sin confirmación del repuesto: ${excluded.take(20).join(', ')}'),
                  for (final item in photos.pending.entries.take(20))
                    Text('${item.key} · ${item.value}'),
                  if (photos.pending.length > 20)
                    Text(
                        '${photos.pending.length} galerías pendientes en total.'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cerrar'),
            ),
            if (photos.pending.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reintentar fotos'),
              ),
          ],
        ),
      );
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
    final ext = widget.fileName.split('.').last.toUpperCase();
    final headerRow = widget.fileMeta.headerRow + widget.sourceRowOffset;
    final sheetName = widget.fileMeta.sheetName;

    return _sectionCard(
      icon: Icons.description_outlined,
      title: widget.fileName,
      subtitle: '$ext · ${widget.preview.headers.length} columnas · '
          '${estimate ?? '?'} repuestos aprox.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ext != 'PDF')
            Text('Encabezados en la fila $headerRow'
                '${sheetName == null ? '' : ' · $sheetName'}'),
          Text(
            'Revisa que el SKU, el nombre, el precio y el stock '
            'correspondan a las columnas de tu archivo.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.documentPhotos != null) ...[
            const Text(
                'Revisa el SKU, los precios y el stock extraídos antes de guardar.'),
            for (final issue in widget.documentPhotos!.issues.take(8))
              Text(issue, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
          ],
          _previewDetailsButton(),
        ],
      ),
    );
  }

  Widget _autoMapReadyBanner() {
    final ready = _mappedRequiredCount == catalogImportRequiredFields.length;
    if (!ready) return const SizedBox.shrink();

    final autoExtras = _captureUnmapped ? _unmappedHeaders().length : 0;
    final detail = autoExtras > 0
        ? 'Columnas obligatorias asociadas. '
            'Se guardarán $autoExtras columnas extra como datos internos.'
        : 'Columnas obligatorias asociadas.';

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
    final step1Done =
        _mappedRequiredCount == catalogImportRequiredFields.length;
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
          '$_mappedRequiredCount/${catalogImportRequiredFields.length} listas',
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
        step(3, 'Confirmar', 'Revisar y guardar', step1Done),
      ],
    );
  }

  Widget _coreMappingCard({required bool desktop}) {
    final optionalFields = _optionalFields.where((f) {
      if (!widget.pagoSoloDivisas) return true;
      // Solo divisas: un precio USD de lista; sin oferta ni % pago USD.
      return f != CatalogImportField.usdPaymentDiscountPct &&
          f != CatalogImportField.salePriceUsd;
    }).toList();

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
          'SKU, nombre, precio y stock son obligatorios. Escribe 0 si el producto no tiene existencias.',
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
                      _optionalExpanded ? Icons.expand_less : Icons.expand_more,
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
        final threeCol = constraints.maxWidth >= 860;
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
        onChanged:
            _importing ? null : (v) => setState(() => _decimalCommaOnPrice = v),
      ),
      _ImportOptionTileData(
        icon: Icons.library_add_outlined,
        title: 'Guardar columnas adicionales',
        subtitle:
            'Si una columna no la mapeas arriba, se guarda automáticamente '
            'con el nombre de la columna del Excel.',
        value: _captureUnmapped,
        onChanged:
            _importing ? null : (v) => setState(() => _captureUnmapped = v),
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
            hint:
                'Visibilidad para tiendas minoristas de códigos que aún no están en inventario',
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

  Widget _previewPanel() {
    final estimate = widget.preview.totalDataRowsEstimate;
    final sample = widget.preview.sampleRows.length;
    return _sectionCard(
      icon: Icons.table_chart_outlined,
      title: 'Vista previa',
      subtitle: estimate == null
          ? 'Muestra del archivo · azul = clave · acento = extra'
          : 'Muestra $sample de ~$estimate · azul = clave · acento = extra',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _previewDetailsButton(),
          const SizedBox(height: 6),
          _PreviewTable(
            headers: widget.preview.headers,
            rows: _reviewedSampleRows,
            coreHeaders: _coreMappedSources,
            erpHeaders: _erpMappedSources,
          ),
        ],
      ),
    );
  }

  Widget _actionBar({required bool desktop}) {
    final ready = _mappedRequiredCount == catalogImportRequiredFields.length;
    final statusText = ready
        ? 'Listo para simular · ${widget.preview.totalDataRowsEstimate ?? '?'} filas estimadas'
        : 'Faltan campos obligatorios por asociar';

    final importButton = FilledButton.icon(
      onPressed:
          _importing || _readingWorkbookPhotos || !ready ? null : _runImport,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
      icon: const Icon(Icons.fact_check_outlined),
      label: const Text('Simular importación'),
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
                    _buildPhotoSection(),
                    const SizedBox(height: 14),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _previewDetailsButton(),
                            const SizedBox(height: 8),
                            _PreviewTable(
                              headers: widget.preview.headers,
                              rows: _reviewedSampleRows,
                              coreHeaders: _coreMappedSources,
                              erpHeaders: _erpMappedSources,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _collapsiblePanel(
                        title: 'Datos extra del ERP',
                        subtitle:
                            _captureUnmapped && _unmappedHeaders().isNotEmpty
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

    return PopScope(
      canPop: !_importing,
      child: Scaffold(
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
                'Revisa tus repuestos y fotos antes de guardar',
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
                    _progressLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (!_savingPhotos) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$_processedRows de ${estimate ?? '?'} filas procesadas',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  if (partial != null && !_savingPhotos) ...[
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

class _PreviewTable extends StatefulWidget {
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
      headingRowHeight: 40,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 52,
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
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          borderRadius: AppDecorations.radius12,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
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
