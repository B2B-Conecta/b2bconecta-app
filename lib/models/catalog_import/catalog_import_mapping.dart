import 'catalog_import_field.dart';

/// Transformaciones opcionales al leer una celda del archivo fuente.
enum CatalogImportTransform {
  none,
  decimalComma,
  booleanSiNo,
  trim,
}

extension CatalogImportTransformX on CatalogImportTransform {
  String get wireValue => switch (this) {
        CatalogImportTransform.none => 'none',
        CatalogImportTransform.decimalComma => 'decimal_comma',
        CatalogImportTransform.booleanSiNo => 'boolean_si_no',
        CatalogImportTransform.trim => 'trim',
      };

  static CatalogImportTransform fromWire(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'decimal_comma':
        return CatalogImportTransform.decimalComma;
      case 'boolean_si_no':
        return CatalogImportTransform.booleanSiNo;
      case 'trim':
        return CatalogImportTransform.trim;
      default:
        return CatalogImportTransform.none;
    }
  }
}

/// Mapeo de una columna del archivo ERP → campo MotoLink.
class CatalogImportColumnBinding {
  const CatalogImportColumnBinding({
    required this.source,
    this.required = false,
    this.transform = CatalogImportTransform.none,
  });

  final String source;
  final bool required;
  final CatalogImportTransform transform;

  factory CatalogImportColumnBinding.fromJson(Map<String, dynamic> json) {
    return CatalogImportColumnBinding(
      source: json['source']?.toString() ?? '',
      required: json['required'] == true,
      transform: CatalogImportTransformX.fromWire(json['transform']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        if (required) 'required': true,
        if (transform != CatalogImportTransform.none)
          'transform': transform.wireValue,
      };
}

enum CatalogImportUpsertMode {
  updateAll,
  insertOnly,
  priceStockOnly,
}

extension CatalogImportUpsertModeX on CatalogImportUpsertMode {
  String get wireValue => switch (this) {
        CatalogImportUpsertMode.updateAll => 'update_all',
        CatalogImportUpsertMode.insertOnly => 'insert_only',
        CatalogImportUpsertMode.priceStockOnly => 'price_stock_only',
      };

  static CatalogImportUpsertMode fromWire(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'insert_only':
        return CatalogImportUpsertMode.insertOnly;
      case 'price_stock_only':
        return CatalogImportUpsertMode.priceStockOnly;
      default:
        return CatalogImportUpsertMode.updateAll;
    }
  }
}

enum CatalogImportFileFormat {
  xlsx,
  csv,
}

extension CatalogImportFileFormatX on CatalogImportFileFormat {
  String get wireValue => name;

  static CatalogImportFileFormat fromWire(String? raw) {
    if (raw?.trim().toLowerCase() == 'csv') return CatalogImportFileFormat.csv;
    return CatalogImportFileFormat.xlsx;
  }
}

/// Payload que envía el frontend con la equivalencia de columnas.
///
/// Ejemplo:
/// ```json
/// {
///   "version": 1,
///   "file": { "name": "erp.xlsx", "format": "xlsx", "header_row": 1 },
///   "options": { "upsert_mode": "update_all", "dry_run": false },
///   "column_map": {
///     "sku": { "source": "Cod_Art", "required": true },
///     "name": { "source": "Descripcion", "required": true },
///     "price_usd": { "source": "Precio_Mayor", "transform": "decimal_comma" }
///   },
///   "custom_fields_map": { "marca": { "source": "Marca_ERP" } }
/// }
/// ```
class CatalogImportMapping {
  const CatalogImportMapping({
    this.version = 1,
    required this.file,
    required this.options,
    required this.columnMap,
    this.customFieldsMap = const {},
    this.aliadoVisibleCustomFieldKeys = const {},
    this.unmappedColumnsPolicy = CatalogUnmappedColumnsPolicy.ignore,
  });

  final int version;
  final CatalogImportFileMeta file;
  final CatalogImportOptions options;
  final Map<String, CatalogImportColumnBinding> columnMap;
  final Map<String, CatalogImportColumnBinding> customFieldsMap;

  /// Claves de `custom_fields_map` visibles para aliados en la ficha.
  final Set<String> aliadoVisibleCustomFieldKeys;
  final CatalogUnmappedColumnsPolicy unmappedColumnsPolicy;

  CatalogImportColumnBinding? bindingFor(CatalogImportField field) {
    return columnMap[field.key];
  }

  factory CatalogImportMapping.fromJson(Map<String, dynamic> json) {
    final columnRaw = json['column_map'];
    final customRaw = json['custom_fields_map'];
    final columnMap = <String, CatalogImportColumnBinding>{};
    if (columnRaw is Map) {
      for (final e in columnRaw.entries) {
        if (e.value is Map) {
          columnMap[e.key.toString()] =
              CatalogImportColumnBinding.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          );
        }
      }
    }
    final customMap = <String, CatalogImportColumnBinding>{};
    if (customRaw is Map) {
      for (final e in customRaw.entries) {
        if (e.value is Map) {
          customMap[e.key.toString()] =
              CatalogImportColumnBinding.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          );
        }
      }
    }
    final visibleRaw = json['aliado_visible_custom_field_keys'];
    final visibleKeys = <String>{};
    if (visibleRaw is List) {
      for (final e in visibleRaw) {
        final k = e.toString().trim();
        if (k.isNotEmpty) visibleKeys.add(k);
      }
    }
    return CatalogImportMapping(
      version: json['version'] is int ? json['version'] as int : 1,
      file: CatalogImportFileMeta.fromJson(
        Map<String, dynamic>.from(json['file'] as Map? ?? {}),
      ),
      options: CatalogImportOptions.fromJson(
        Map<String, dynamic>.from(json['options'] as Map? ?? {}),
      ),
      columnMap: columnMap,
      customFieldsMap: customMap,
      aliadoVisibleCustomFieldKeys: visibleKeys,
      unmappedColumnsPolicy: CatalogUnmappedColumnsPolicyX.fromWire(
        json['unmapped_columns_policy']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'file': file.toJson(),
        'options': options.toJson(),
        'column_map': {
          for (final e in columnMap.entries) e.key: e.value.toJson(),
        },
        if (customFieldsMap.isNotEmpty)
          'custom_fields_map': {
            for (final e in customFieldsMap.entries) e.key: e.value.toJson(),
          },
        if (aliadoVisibleCustomFieldKeys.isNotEmpty)
          'aliado_visible_custom_field_keys':
              aliadoVisibleCustomFieldKeys.toList()..sort(),
        'unmapped_columns_policy': unmappedColumnsPolicy.wireValue,
      };

  /// Valida que los campos obligatorios estén mapeados.
  List<String> missingRequiredFields() {
    final missing = <String>[];
    for (final field in catalogImportRequiredFields) {
      final binding = bindingFor(field);
      if (binding == null || binding.source.trim().isEmpty) {
        missing.add(field.key);
      }
    }
    return missing;
  }
}

enum CatalogUnmappedColumnsPolicy {
  ignore,
  captureAsCustom,
}

extension CatalogUnmappedColumnsPolicyX on CatalogUnmappedColumnsPolicy {
  String get wireValue => switch (this) {
        CatalogUnmappedColumnsPolicy.ignore => 'ignore',
        CatalogUnmappedColumnsPolicy.captureAsCustom => 'capture_as_custom',
      };

  static CatalogUnmappedColumnsPolicy fromWire(String? raw) {
    if (raw?.trim().toLowerCase() == 'capture_as_custom') {
      return CatalogUnmappedColumnsPolicy.captureAsCustom;
    }
    return CatalogUnmappedColumnsPolicy.ignore;
  }
}

class CatalogImportFileMeta {
  const CatalogImportFileMeta({
    this.name = '',
    this.format = CatalogImportFileFormat.xlsx,
    this.sheetName,
    this.headerRow = 1,
    this.dataStartsAtRow = 2,
    this.encoding = 'utf-8',
    this.csvDelimiter = ',',
  });

  final String name;
  final CatalogImportFileFormat format;
  final String? sheetName;
  final int headerRow;
  final int dataStartsAtRow;
  final String encoding;
  final String csvDelimiter;

  factory CatalogImportFileMeta.fromJson(Map<String, dynamic> json) {
    return CatalogImportFileMeta(
      name: json['name']?.toString() ?? '',
      format: CatalogImportFileFormatX.fromWire(json['format']?.toString()),
      sheetName: json['sheet_name']?.toString(),
      headerRow: _asInt(json['header_row'], fallback: 1),
      dataStartsAtRow: _asInt(json['data_starts_at_row'], fallback: 2),
      encoding: json['encoding']?.toString() ?? 'utf-8',
      csvDelimiter: json['csv_delimiter']?.toString() ?? ',',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'format': format.wireValue,
        if (sheetName != null) 'sheet_name': sheetName,
        'header_row': headerRow,
        'data_starts_at_row': dataStartsAtRow,
        'encoding': encoding,
        if (format == CatalogImportFileFormat.csv)
          'csv_delimiter': csvDelimiter,
      };

  static int _asInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}

class CatalogImportOptions {
  const CatalogImportOptions({
    this.upsertMode = CatalogImportUpsertMode.updateAll,
    this.skipExampleRows = true,
    this.dryRun = false,
    this.newProductsActive = false,
    this.batchSize = 500,
    this.pagoSoloDivisas = false,
  });

  final CatalogImportUpsertMode upsertMode;
  final bool skipExampleRows;
  final bool dryRun;
  final bool newProductsActive;
  final int batchSize;
  final bool pagoSoloDivisas;

  factory CatalogImportOptions.fromJson(Map<String, dynamic> json) {
    return CatalogImportOptions(
      upsertMode: CatalogImportUpsertModeX.fromWire(
        json['upsert_mode']?.toString(),
      ),
      skipExampleRows: json['skip_example_rows'] != false,
      dryRun: json['dry_run'] == true,
      newProductsActive: json['new_products_active'] == true,
      batchSize: CatalogImportFileMeta._asInt(json['batch_size'], fallback: 500),
      pagoSoloDivisas: json['pago_solo_divisas'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'upsert_mode': upsertMode.wireValue,
        'skip_example_rows': skipExampleRows,
        'dry_run': dryRun,
        'new_products_active': newProductsActive,
        'batch_size': batchSize,
        if (pagoSoloDivisas) 'pago_solo_divisas': true,
      };
}
