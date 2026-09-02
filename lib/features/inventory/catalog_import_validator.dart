import 'catalog_import/catalog_import_field.dart';
import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'excel_catalog_service.dart';
import 'product_custom_fields.dart';
import 'product_min_order_qty.dart';
import 'product_volume_tiers.dart';

/// Fila normalizada lista para enviar al RPC `importador_bulk_upsert_products`.
class CatalogImportNormalizedRow {
  const CatalogImportNormalizedRow({
    required this.rowIndex,
    required this.sku,
    required this.name,
    required this.priceUsd,
    required this.stock,
    this.minOrderQty,
    this.description,
    this.category,
    this.compatibility,
    this.imageUrl,
    this.salePriceUsd,
    this.hasWarranty = false,
    this.discountRules,
    this.customFields = const {},
    this.priceColumn,
    this.priceRaw,
  });

  final int rowIndex;
  final String sku;
  final String name;
  final double priceUsd;
  final int stock;
  final int? minOrderQty;
  final String? description;
  final String? category;
  final String? compatibility;
  final String? imageUrl;
  final double? salePriceUsd;
  final bool hasWarranty;
  final Map<String, dynamic>? discountRules;
  final Map<String, dynamic> customFields;

  /// Columna de origen del precio (para mensajes de error).
  final String? priceColumn;
  final String? priceRaw;

  Map<String, dynamic> toRpcJson() {
    final payload = <String, dynamic>{
      'row_index': rowIndex,
      'sku': sku,
      'name': name,
      'price_usd': priceUsd,
      'stock': stock,
      'has_warranty': hasWarranty,
    };
    if (minOrderQty != null) payload['min_order_qty'] = minOrderQty;
    if (description != null) payload['description'] = description;
    if (category != null) payload['category'] = category;
    if (compatibility != null) payload['compatibility'] = compatibility;
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (salePriceUsd != null) payload['sale_price_usd'] = salePriceUsd;
    if (discountRules != null) payload['discount_rules'] = discountRules;
    if (customFields.isNotEmpty) payload['custom_fields'] = customFields;
    return payload;
  }
}

/// Resultado intermedio del parseo + validación local (sin persistir).
class CatalogImportParseBatch {
  const CatalogImportParseBatch({
    required this.validRows,
    required this.errors,
  });

  final List<CatalogImportNormalizedRow> validRows;
  final List<CatalogImportRowError> errors;
}

/// Pipeline de validación de alto rendimiento (O(n), memoria acotada por lote).
class CatalogImportValidator {
  CatalogImportValidator._();

  static const maxErrorsPerBatch = 200;

  /// Valida filas ya mapeadas y detecta SKU duplicados dentro del lote.
  static CatalogImportParseBatch validateBatch(
    List<CatalogImportNormalizedRow> rows, {
    int maxErrors = maxErrorsPerBatch,
  }) {
    final valid = <CatalogImportNormalizedRow>[];
    final errors = <CatalogImportRowError>[];
    final seenSkus = <String>{};

    for (final row in rows) {
      if (errors.length >= maxErrors) break;

      final sku = row.sku.trim();
      if (sku.isEmpty) {
        errors.add(CatalogImportRowError(
          rowIndex: row.rowIndex,
          code: 'REQUIRED_SKU',
          message: 'SKU obligatorio',
        ));
        continue;
      }

      final skuKey = sku.toLowerCase();
      if (seenSkus.contains(skuKey)) {
        errors.add(CatalogImportRowError(
          rowIndex: row.rowIndex,
          sku: sku,
          code: 'DUPLICATE_SKU_IN_FILE',
          message: 'SKU duplicado en el archivo',
        ));
        continue;
      }
      seenSkus.add(skuKey);

      if (row.name.trim().isEmpty) {
        errors.add(CatalogImportRowError(
          rowIndex: row.rowIndex,
          sku: sku,
          code: 'REQUIRED_NAME',
          message: 'Nombre obligatorio',
        ));
        continue;
      }

      if (row.priceUsd.isNaN || row.priceUsd < 0) {
        errors.add(CatalogImportRowError(
          rowIndex: row.rowIndex,
          sku: sku,
          code: 'INVALID_PRICE',
          column: row.priceColumn,
          rawValue: row.priceRaw,
          message: _invalidPriceMessage(row),
        ));
        continue;
      }

      if (row.stock < 0) {
        errors.add(CatalogImportRowError(
          rowIndex: row.rowIndex,
          sku: sku,
          code: 'INVALID_STOCK',
          message: 'Stock inválido',
        ));
        continue;
      }

      if (row.minOrderQty != null &&
          row.minOrderQty! < ProductMinOrderQty.platformFloor) {
        errors.add(CatalogImportRowError(
          rowIndex: row.rowIndex,
          sku: sku,
          code: 'INVALID_MIN_ORDER_QTY',
          message:
              'La cantidad mínima de pedido debe ser ${ProductMinOrderQty.platformFloor} o más',
        ));
        continue;
      }

      final sale = row.salePriceUsd;
      if (sale != null && (sale <= 0 || sale >= row.priceUsd)) {
        errors.add(CatalogImportRowError(
          rowIndex: row.rowIndex,
          sku: sku,
          code: 'INVALID_SALE_PRICE',
          message: 'Precio oferta debe ser > 0 y < precio lista',
        ));
        continue;
      }

      valid.add(row);
    }

    return CatalogImportParseBatch(validRows: valid, errors: errors);
  }

  /// Construye una fila normalizada a partir de celdas crudas + mapeo.
  static CatalogImportNormalizedRow? mapRawRow({
    required int rowIndex,
    required Map<String, String> rawByHeader,
    required CatalogImportMapping mapping,
  }) {
    String? readField(String targetKey) {
      final binding = mapping.columnMap[targetKey];
      if (binding == null) return null;
      final raw = rawByHeader[binding.source];
      if (raw == null) return null;
      return _applyTransform(raw, binding.transform);
    }

    String? readCustom(String customKey) {
      final binding = mapping.customFieldsMap[customKey];
      if (binding == null) return null;
      final raw = rawByHeader[binding.source];
      if (raw == null) return null;
      return _applyTransform(raw, binding.transform);
    }

    String? readUntransformed(String targetKey) {
      final binding = mapping.columnMap[targetKey];
      if (binding == null) return null;
      return rawByHeader[binding.source];
    }

    final sku = readField(CatalogImportField.sku.key)?.trim() ?? '';
    if (sku.isEmpty) return null;
    if (mapping.options.skipExampleRows &&
        sku.toUpperCase().startsWith('EJEMPLO')) {
      return null;
    }

    final name = readField(CatalogImportField.name.key)?.trim() ?? '';
    final priceBinding = mapping.columnMap[CatalogImportField.priceUsd.key];
    final priceRaw = readUntransformed(CatalogImportField.priceUsd.key);
    final stockRaw = readUntransformed(CatalogImportField.stock.key);
    final minQtyRaw = readUntransformed(CatalogImportField.minOrderQty.key);

    final price = parseImportNumber(priceRaw);
    final stock = _parseStock(stockRaw);
    final minOrderQty = _parseMinOrderQty(minQtyRaw);

    final saleRaw = readUntransformed(CatalogImportField.salePriceUsd.key);
    final sale = saleRaw == null || saleRaw.trim().isEmpty
        ? null
        : parseImportNumber(saleRaw);

    final usdPctRaw =
        readUntransformed(CatalogImportField.usdPaymentDiscountPct.key);
    final tiersRaw = readField(CatalogImportField.volumeTiersJson.key);
    double? usdPct;
    if (usdPctRaw != null && usdPctRaw.trim().isNotEmpty) {
      usdPct = parseImportNumber(usdPctRaw);
      if (usdPct == 0) usdPct = null;
    }

    final discountRules = _buildDiscountRules(
      usdPct: mapping.options.pagoSoloDivisas ? null : usdPct,
      tiersJson: tiersRaw,
    );

    final customFields = <String, dynamic>{};

    bool hasWarranty = false;
    final warrantyRaw = readField(CatalogImportField.hasWarranty.key);
    if (warrantyRaw != null && warrantyRaw.trim().isNotEmpty) {
      final parsed = ExcelCatalogService.parseGarantiaCell(
        warrantyRaw,
        rowIndex: rowIndex,
        sku: sku,
      );
      hasWarranty = parsed.hasWarranty;
      if (parsed.warrantyDays != null && parsed.warrantyDays! > 0) {
        customFields['warranty_days'] = parsed.warrantyDays;
      }
    }

    for (final key in mapping.customFieldsMap.keys) {
      final v = readCustom(key);
      if (v != null && v.trim().isNotEmpty) {
        customFields[key] = v.trim();
      }
    }

    if (mapping.unmappedColumnsPolicy ==
        CatalogUnmappedColumnsPolicy.captureAsCustom) {
      final mappedSources = {
        ...mapping.columnMap.values.map((b) => b.source),
        ...mapping.customFieldsMap.values.map((b) => b.source),
      };
      for (final entry in rawByHeader.entries) {
        if (mappedSources.contains(entry.key)) continue;
        final v = entry.value.trim();
        if (v.isEmpty) continue;
        customFields['col_${_slugHeader(entry.key)}'] = v;
      }
    }

    final customFieldsPayload = buildCustomFieldsPayload(
      values: customFields,
      aliadoVisibleKeys: mapping.aliadoVisibleCustomFieldKeys,
    );

    return CatalogImportNormalizedRow(
      rowIndex: rowIndex,
      sku: sku,
      name: name,
      priceUsd: price ?? double.nan,
      stock: stock,
      minOrderQty: minOrderQty,
      description: _nullable(readField(CatalogImportField.description.key)),
      category: _nullable(readField(CatalogImportField.category.key)),
      compatibility: _nullable(readField(CatalogImportField.compatibility.key)),
      imageUrl: _nullable(readField(CatalogImportField.imageUrl.key)),
      salePriceUsd: sale,
      hasWarranty: hasWarranty,
      discountRules: discountRules,
      customFields: customFieldsPayload,
      priceColumn: priceBinding?.source,
      priceRaw: priceRaw,
    );
  }

  static Map<String, dynamic>? _buildDiscountRules({
    double? usdPct,
    String? tiersJson,
  }) {
    final tiers = parseProductVolumeTiers(
      parseVolumeTiersJsonCell(tiersJson),
    );
    return buildProductDiscountRules(
      volumeTiers: tiers,
      usdPaymentDiscountPct: usdPct,
    );
  }

  static String? _nullable(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _applyTransform(
    String raw,
    CatalogImportTransform transform,
  ) {
    switch (transform) {
      case CatalogImportTransform.decimalComma:
        return raw.replaceAll(',', '.');
      case CatalogImportTransform.trim:
        return raw.trim();
      case CatalogImportTransform.booleanSiNo:
      case CatalogImportTransform.none:
        return raw;
    }
  }

  /// Acepta enteros, decimales con `.` o `,`, miles, `$` / `USD` y precio 0.
  static double? parseImportNumber(String? raw) {
    if (raw == null) return null;
    var t = raw.trim().replaceAll('\u00A0', ' ');
    if (t.isEmpty) return null;
    t = t.replaceAll(RegExp(r'(usd|us\$)', caseSensitive: false), '');
    t = t.replaceAll('\$', '');
    t = t.replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) return null;

    final lastComma = t.lastIndexOf(',');
    final lastDot = t.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        t = t.replaceAll('.', '').replaceAll(',', '.');
      } else {
        t = t.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      final decimals = t.length - lastComma - 1;
      if (decimals > 0 && decimals <= 2) {
        t = t.replaceAll(',', '.');
      } else {
        t = t.replaceAll(',', '');
      }
    }

    return double.tryParse(t);
  }

  static int _parseStock(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final n = parseImportNumber(raw);
    if (n == null || n.isNaN) return -1;
    return n.round();
  }

  static int? _parseMinOrderQty(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final n = parseImportNumber(raw);
    if (n == null || n.isNaN) return 0;
    return n.round();
  }

  static String _invalidPriceMessage(CatalogImportNormalizedRow row) {
    final col = row.priceColumn?.trim();
    final raw = row.priceRaw?.trim() ?? '';
    final clipped = _clip(raw, 80);
    if (col == null || col.isEmpty) {
      if (raw.contains(';')) {
        return 'Precio inválido: no se partieron las columnas (¿CSV con '
            'punto y coma?). Valor: "$clipped"';
      }
      return raw.isEmpty
          ? 'Precio inválido: columna de precio vacía o no mapeada'
          : 'Precio inválido: "$clipped"';
    }
    if (raw.isEmpty) {
      return 'Precio inválido (columna "$col" vacía)';
    }
    if (raw.contains(';') && !raw.contains(',')) {
      return 'Precio inválido (columna "$col": "$clipped"). El archivo parece '
          'CSV con punto y coma; vuelva a subirlo para autodetectar el separador.';
    }
    return 'Precio inválido (columna "$col": "$clipped")';
  }

  static String _clip(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }

  static String _slugHeader(String header) {
    return header
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
