import 'catalog_import/catalog_import_result.dart';
import 'catalog_import_validator.dart';

/// Tipo de problema de una fila, para agrupar listas repetidas.
enum CatalogImportIssueKind {
  emptyStock,
  invalidStock,
  missingPrice,
  invalidPrice,
  missingSku,
  duplicateSku,
  invalidSku,
  missingName,
  other,
}

extension CatalogImportIssueKindX on CatalogImportIssueKind {
  String get title => switch (this) {
        CatalogImportIssueKind.emptyStock => 'Stock vacío',
        CatalogImportIssueKind.invalidStock => 'Stock inválido',
        CatalogImportIssueKind.missingPrice => 'Precio vacío',
        CatalogImportIssueKind.invalidPrice => 'Precio inválido',
        CatalogImportIssueKind.missingSku => 'SKU faltante',
        CatalogImportIssueKind.duplicateSku => 'SKU duplicado',
        CatalogImportIssueKind.invalidSku => 'SKU inválido',
        CatalogImportIssueKind.missingName => 'Nombre faltante',
        CatalogImportIssueKind.other => 'Otros',
      };

  /// Impide guardar esa fila. El resto del lote puede seguir.
  bool get blocking => true;

  static CatalogImportIssueKind fromError(CatalogImportRowError error) {
    final code = error.code.toUpperCase();
    final message = error.message.toLowerCase();
    if (code == 'REQUIRED_SKU' || message.contains('sku obligatorio')) {
      return CatalogImportIssueKind.missingSku;
    }
    if (code == 'DUPLICATE_SKU_IN_FILE' || message.contains('sku duplicado')) {
      return CatalogImportIssueKind.duplicateSku;
    }
    if (code == 'INVALID_SKU') return CatalogImportIssueKind.invalidSku;
    if (code == 'REQUIRED_NAME' || message.contains('nombre obligatorio')) {
      return CatalogImportIssueKind.missingName;
    }
    if (message.contains('stock vacío') || message.contains('stock vacio')) {
      return CatalogImportIssueKind.emptyStock;
    }
    if (code == 'INVALID_STOCK' || message.contains('stock inválido') ||
        message.contains('stock invalido')) {
      return CatalogImportIssueKind.invalidStock;
    }
    if (code == 'INVALID_PRICE' || message.contains('precio')) {
      if (message.contains('vacía') || message.contains('vacia')) {
        return CatalogImportIssueKind.missingPrice;
      }
      return CatalogImportIssueKind.invalidPrice;
    }
    return CatalogImportIssueKind.other;
  }
}

class CatalogImportErrorGroup {
  const CatalogImportErrorGroup({
    required this.kind,
    required this.errors,
  });

  final CatalogImportIssueKind kind;
  final List<CatalogImportRowError> errors;

  String get title => kind.title;
  bool get blocking => kind.blocking;
  int get count => errors.length;
  bool get canFillStock => kind == CatalogImportIssueKind.emptyStock;
}

List<CatalogImportErrorGroup> groupCatalogImportErrors(
  List<CatalogImportRowError> errors,
) {
  final buckets = <CatalogImportIssueKind, List<CatalogImportRowError>>{};
  for (final error in errors) {
    final kind = CatalogImportIssueKindX.fromError(error);
    buckets.putIfAbsent(kind, () => []).add(error);
  }
  const order = CatalogImportIssueKind.values;
  return [
    for (final kind in order)
      if (buckets[kind] case final rows?)
        CatalogImportErrorGroup(kind: kind, errors: rows),
  ];
}

/// Huecos visibles en la muestra, antes de simular el archivo completo.
class CatalogImportSampleScan {
  const CatalogImportSampleScan({
    required this.sampleSize,
    required this.emptyStock,
    required this.invalidStock,
    required this.emptyPrice,
    required this.invalidPrice,
    required this.emptySku,
    required this.emptyName,
    required this.commaPrices,
    required this.dotPrices,
    required this.stockMapped,
    required this.priceMapped,
    required this.skuMapped,
    required this.nameMapped,
  });

  final int sampleSize;
  final int emptyStock;
  final int invalidStock;
  final int emptyPrice;
  final int invalidPrice;
  final int emptySku;
  final int emptyName;
  final int commaPrices;
  final int dotPrices;
  final bool stockMapped;
  final bool priceMapped;
  final bool skuMapped;
  final bool nameMapped;

  bool get commaAmbiguous => commaPrices > 0 && dotPrices > 0;
  bool get prefersComma => commaPrices > 0;

  bool get stockGap =>
      !stockMapped || emptyStock > 0 || invalidStock > 0;

  bool get priceGap => !priceMapped || emptyPrice > 0 || invalidPrice > 0;

  bool get hasBlockingGaps =>
      !skuMapped ||
      !nameMapped ||
      emptySku > 0 ||
      emptyName > 0 ||
      stockGap ||
      priceGap;

  static CatalogImportSampleScan inspect({
    required List<Map<String, String>> rows,
    required String? skuColumn,
    required String? nameColumn,
    required String? priceColumn,
    required String? stockColumn,
    int? emptyStockFill,
    double? emptyPriceFill,
  }) {
    var emptyStock = 0;
    var invalidStock = 0;
    var emptyPrice = 0;
    var invalidPrice = 0;
    var emptySku = 0;
    var emptyName = 0;
    var commaPrices = 0;
    var dotPrices = 0;

    final stockMapped = stockColumn != null && stockColumn.isNotEmpty;
    final priceMapped = priceColumn != null && priceColumn.isNotEmpty;
    final skuMapped = skuColumn != null && skuColumn.isNotEmpty;
    final nameMapped = nameColumn != null && nameColumn.isNotEmpty;

    for (final row in rows) {
      if (skuMapped && (row[skuColumn]?.trim().isEmpty ?? true)) emptySku++;
      if (nameMapped && (row[nameColumn]?.trim().isEmpty ?? true)) emptyName++;

      if (priceMapped) {
        final raw = row[priceColumn]?.trim() ?? '';
        if (raw.isEmpty) {
          if (emptyPriceFill == null) emptyPrice++;
        } else {
          if (RegExp(r'\d+,\d+').hasMatch(raw)) commaPrices++;
          if (RegExp(r'\d+\.\d+').hasMatch(raw)) dotPrices++;
          if (CatalogImportValidator.parseImportNumber(raw) == null &&
              emptyPriceFill == null) {
            invalidPrice++;
          }
        }
      }

      if (stockMapped) {
        final raw = row[stockColumn]?.trim() ?? '';
        if (raw.isEmpty) {
          if (emptyStockFill == null) emptyStock++;
        } else {
          final n = CatalogImportValidator.parseImportNumber(raw);
          if (n == null || n < 0 || n != n.truncateToDouble()) {
            invalidStock++;
          }
        }
      }
    }

    if (!stockMapped && emptyStockFill == null && rows.isNotEmpty) {
      emptyStock = rows.length;
    }
    if (!priceMapped && emptyPriceFill == null && rows.isNotEmpty) {
      emptyPrice = rows.length;
    }

    return CatalogImportSampleScan(
      sampleSize: rows.length,
      emptyStock: emptyStock,
      invalidStock: invalidStock,
      emptyPrice: emptyPrice,
      invalidPrice: invalidPrice,
      emptySku: emptySku,
      emptyName: emptyName,
      commaPrices: commaPrices,
      dotPrices: dotPrices,
      stockMapped: stockMapped || emptyStockFill != null,
      priceMapped: priceMapped || emptyPriceFill != null,
      skuMapped: skuMapped,
      nameMapped: nameMapped,
    );
  }
}

/// Texto único del pie: muestra, simulación y fotos usan los mismos números.
class CatalogImportLiveStatus {
  const CatalogImportLiveStatus({
    required this.message,
    required this.readyToSimulate,
    required this.clean,
    required this.stockNeedsAction,
    required this.priceNeedsAction,
    required this.commaNeedsAction,
  });

  final String message;
  final bool readyToSimulate;
  final bool clean;
  final bool stockNeedsAction;
  final bool priceNeedsAction;
  final bool commaNeedsAction;

  static CatalogImportLiveStatus resolve({
    required List<String> missingLabels,
    required CatalogImportSampleScan scan,
    required int? estimatedRows,
    required int? emptyStockFill,
    required double? emptyPriceFill,
    required bool decimalCommaOn,
    CatalogImportResult? lastRun,
    int detectedPhotos = 0,
    int includedPhotos = 0,
  }) {
    final rows = estimatedRows ?? scan.sampleSize;
    final photos = detectedPhotos <= 0
        ? ''
        : ' · $includedPhotos/$detectedPhotos fotos';
    final commaNeeds =
        !decimalCommaOn && (scan.prefersComma || scan.commaAmbiguous);

    if (lastRun != null) {
      return CatalogImportLiveStatus(
        message: '${lastRun.successCount} listas · '
            '${lastRun.errorCount} con error · '
            '${lastRun.skipped} omitidas · $rows filas$photos',
        readyToSimulate: missingLabels.isEmpty,
        clean: lastRun.errorCount == 0 && missingLabels.isEmpty,
        stockNeedsAction: false,
        priceNeedsAction: false,
        commaNeedsAction: commaNeeds,
      );
    }

    if (missingLabels.isNotEmpty) {
      return CatalogImportLiveStatus(
        message: 'Faltan: ${missingLabels.join(', ')}',
        readyToSimulate: false,
        clean: false,
        stockNeedsAction: missingLabels.any((l) =>
            l.toLowerCase().contains('stock') ||
            l.toLowerCase().contains('existencia')),
        priceNeedsAction:
            missingLabels.any((l) => l.toLowerCase().contains('precio')),
        commaNeedsAction: commaNeeds,
      );
    }

    if (scan.emptyStock > 0 && emptyStockFill == null) {
      final detail = scan.sampleSize > 0 && scan.emptyStock == scan.sampleSize
          ? 'Stock vacío en las $rows filas'
          : 'Stock vacío en ${scan.emptyStock} de ${scan.sampleSize} filas de muestra';
      return CatalogImportLiveStatus(
        message: '$detail$photos',
        readyToSimulate: true,
        clean: false,
        stockNeedsAction: true,
        priceNeedsAction: scan.emptyPrice > 0 && emptyPriceFill == null,
        commaNeedsAction: commaNeeds,
      );
    }

    if (scan.emptyPrice > 0 && emptyPriceFill == null) {
      final detail = scan.sampleSize > 0 && scan.emptyPrice == scan.sampleSize
          ? 'Precio vacío en las $rows filas'
          : 'Precio vacío en ${scan.emptyPrice} de ${scan.sampleSize} filas de muestra';
      return CatalogImportLiveStatus(
        message: '$detail$photos',
        readyToSimulate: true,
        clean: false,
        stockNeedsAction: false,
        priceNeedsAction: true,
        commaNeedsAction: commaNeeds,
      );
    }

    if (scan.emptySku > 0 || scan.emptyName > 0 || scan.invalidStock > 0) {
      final bits = <String>[
        if (scan.emptySku > 0) 'SKU vacío (${scan.emptySku})',
        if (scan.emptyName > 0) 'Nombre vacío (${scan.emptyName})',
        if (scan.invalidStock > 0) 'Stock inválido (${scan.invalidStock})',
      ];
      return CatalogImportLiveStatus(
        message: '${bits.join(' · ')} · $rows filas$photos',
        readyToSimulate: true,
        clean: false,
        stockNeedsAction: scan.invalidStock > 0,
        priceNeedsAction: false,
        commaNeedsAction: commaNeeds,
      );
    }

    final fillNote = emptyStockFill == null ? '' : ' · stock vacío = $emptyStockFill';
    final priceNote =
        emptyPriceFill == null ? '' : ' · precio vacío = $emptyPriceFill';
    return CatalogImportLiveStatus(
      message: 'Listo · $rows filas$fillNote$priceNote$photos',
      readyToSimulate: true,
      clean: true,
      stockNeedsAction: false,
      priceNeedsAction: false,
      commaNeedsAction: commaNeeds,
    );
  }
}
