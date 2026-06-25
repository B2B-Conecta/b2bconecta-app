/// Error de validación o persistencia en una fila concreta.
class CatalogImportRowError {
  const CatalogImportRowError({
    required this.rowIndex,
    required this.code,
    required this.message,
    this.sku,
  });

  final int rowIndex;
  final String? sku;
  final String code;
  final String message;

  factory CatalogImportRowError.fromJson(Map<String, dynamic> json) {
    return CatalogImportRowError(
      rowIndex: json['row_index'] is int
          ? json['row_index'] as int
          : int.tryParse(json['row_index']?.toString() ?? '') ?? 0,
      sku: json['sku']?.toString(),
      code: json['code']?.toString() ?? 'UNKNOWN',
      message: json['message']?.toString() ?? 'Error desconocido',
    );
  }

  Map<String, dynamic> toJson() => {
        'row_index': rowIndex,
        if (sku != null) 'sku': sku,
        'code': code,
        'message': message,
      };
}

/// Respuesta agregada de la API / RPC tras procesar uno o varios lotes.
class CatalogImportResult {
  const CatalogImportResult({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.validationErrors = const [],
    this.persistenceErrors = const [],
    this.dryRun = false,
  });

  final int inserted;
  final int updated;
  final int skipped;
  final List<CatalogImportRowError> validationErrors;
  final List<CatalogImportRowError> persistenceErrors;
  final bool dryRun;

  int get successCount => inserted + updated;

  int get errorCount => validationErrors.length + persistenceErrors.length;

  bool get hasErrors => errorCount > 0;

  List<CatalogImportRowError> get allErrors => [
        ...validationErrors,
        ...persistenceErrors,
      ];

  factory CatalogImportResult.fromRpcJson(Map<String, dynamic> json) {
    final errorsRaw = json['errors'];
    final errors = <CatalogImportRowError>[];
    if (errorsRaw is List) {
      for (final e in errorsRaw) {
        if (e is Map) {
          errors.add(
            CatalogImportRowError.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return CatalogImportResult(
      inserted: _asInt(json['inserted']),
      updated: _asInt(json['updated']),
      skipped: _asInt(json['skipped']),
      persistenceErrors: errors,
    );
  }

  CatalogImportResult merge(CatalogImportResult other) {
    return CatalogImportResult(
      inserted: inserted + other.inserted,
      updated: updated + other.updated,
      skipped: skipped + other.skipped,
      validationErrors: [...validationErrors, ...other.validationErrors],
      persistenceErrors: [...persistenceErrors, ...other.persistenceErrors],
      dryRun: dryRun || other.dryRun,
    );
  }

  Map<String, dynamic> toJson() => {
        'inserted': inserted,
        'updated': updated,
        'skipped': skipped,
        'success_count': successCount,
        'error_count': errorCount,
        'dry_run': dryRun,
        'errors': allErrors.map((e) => e.toJson()).toList(),
      };

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// Vista previa de cabeceras detectadas en el archivo (paso 1 del wizard).
class CatalogImportPreview {
  const CatalogImportPreview({
    required this.headers,
    required this.sampleRows,
    this.totalDataRowsEstimate,
  });

  final List<String> headers;
  final List<Map<String, String>> sampleRows;
  final int? totalDataRowsEstimate;
}
