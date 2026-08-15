import 'catalog_import/catalog_import_field.dart';
import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'excel_catalog_service.dart';
import 'product_custom_fields.dart';
import 'product_volume_tiers.dart';

/// Fila normalizada lista para enviar al RPC `importador_bulk_upsert_products`.
class CatalogImportNormalizedRow {
  const CatalogImportNormalizedRow({
    required this.rowIndex,
    required this.sku,
    required this.name,
    required this.priceUsd,
    required this.stock,
    this.description,
    this.category,
    this.compatibility,
    this.imageUrl,
    this.salePriceUsd,
    this.hasWarranty = false,
    this.discountRules,
    this.customFields = const {},
  });

  final int rowIndex;
  final String sku;
  final String name;
  final double priceUsd;
  final int stock;
  final String? description;
  final String? category;
  final String? compatibility;
  final String? imageUrl;
  final double? salePriceUsd;
  final bool hasWarranty;
  final Map<String, dynamic>? discountRules;
  final Map<String, dynamic> customFields;

  Map<String, dynamic> toRpcJson() {
    final payload = <String, dynamic>{
      'row_index': rowIndex,
      'sku': sku,
      'name': name,
      'price_usd': priceUsd,
      'stock': stock,
      'has_warranty': hasWarranty,
    };
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
          message: 'Precio inválido',
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

    final sku = readField(CatalogImportField.sku.key)?.trim() ?? '';
    if (sku.isEmpty) return null;
    if (mapping.options.skipExampleRows &&
        sku.toUpperCase().startsWith('EJEMPLO')) {
      return null;
    }

    final name = readField(CatalogImportField.name.key)?.trim() ?? '';
    final priceRaw = readField(CatalogImportField.priceUsd.key);
    final stockRaw = readField(CatalogImportField.stock.key);

    final price = _parseDouble(priceRaw);
    final stock = _parseInt(stockRaw);

    final saleRaw = readField(CatalogImportField.salePriceUsd.key);
    final sale = saleRaw == null || saleRaw.trim().isEmpty
        ? null
        : _parseDouble(saleRaw);

    final usdPctRaw = readField(CatalogImportField.usdPaymentDiscountPct.key);
    final tiersRaw = readField(CatalogImportField.volumeTiersJson.key);
    double? usdPct;
    if (usdPctRaw != null && usdPctRaw.trim().isNotEmpty) {
      usdPct = _parseDouble(usdPctRaw);
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
      stock: stock ?? -1,
      description: _nullable(readField(CatalogImportField.description.key)),
      category: _nullable(readField(CatalogImportField.category.key)),
      compatibility: _nullable(readField(CatalogImportField.compatibility.key)),
      imageUrl: _nullable(readField(CatalogImportField.imageUrl.key)),
      salePriceUsd: sale,
      hasWarranty: hasWarranty,
      discountRules: discountRules,
      customFields: customFieldsPayload,
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

  static double? _parseDouble(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  static int? _parseInt(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  static String _slugHeader(String header) {
    return header
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
