import 'catalog_import/catalog_import_field.dart';

/// Sugiere columnas del archivo ERP para cada campo B2B Conecta.
class CatalogImportHeaderGuess {
  CatalogImportHeaderGuess._();

  static final _patterns = <CatalogImportField, List<String>>{
    CatalogImportField.sku: [
      'sku',
      'cod_art',
      'cod_producto',
      'codigo_producto',
      'codigo_de_producto',
      'codigo_del_producto',
      'codigo_articulo',
      'codigo',
      'cod',
      'articulo',
      'art',
      'ref',
      'item',
      'part',
      'referencia',
    ],
    CatalogImportField.name: [
      'nombre',
      'nombre_comercial',
      'nombre_del_producto',
      'nombre_del_repuesto',
      'name',
      'producto',
      'titulo',
      'descripcion',
      'description',
      'desc',
    ],
    CatalogImportField.description: [
      'descripcion_larga',
      'detalle',
      'description',
      'descripcion',
      'notas',
    ],
    CatalogImportField.priceUsd: [
      'precio',
      'price',
      'precio_de_lista',
      'precio_mayor',
      'precio_mayorista',
      'precio_usd',
      'pvp',
      'costo',
      'wholesale',
    ],
    CatalogImportField.salePriceUsd: [
      'precio_oferta',
      'oferta',
      'sale',
      'promo',
      'precio_promo',
    ],
    CatalogImportField.stock: [
      'stock',
      'existencia',
      'existencias',
      'exist',
      'cantidad_en_stock',
      'cantidad_disponible',
      'inventario',
      'disponible',
    ],
    CatalogImportField.minOrderQty: [
      'cantidad_minima',
      'min_order_qty',
      'min_order',
      'pedido_minimo',
      'moq',
      'minimo_pedido',
    ],
    CatalogImportField.category: [
      'categoria',
      'category',
      'familia',
      'rubro',
      'linea',
    ],
    CatalogImportField.compatibility: [
      'compatibilidad',
      'compatibility',
      'modelos',
      'aplicacion',
      'fitment',
    ],
    CatalogImportField.imageUrl: [
      'url_imagen',
      'image_url',
      'imagen',
      'foto',
      'image',
    ],
    CatalogImportField.parentSku: [
      'parent_sku',
      'sku_padre',
      'codigo_padre',
      'producto_padre',
    ],
    CatalogImportField.variantAttributeName: [
      'atributo',
      'nombre_atributo',
      'presentacion',
      'medida',
      'talla',
    ],
    CatalogImportField.variantAttributeValue: [
      'valor_atributo',
      'atributo_valor',
      'opcion',
      'variante',
    ],
    CatalogImportField.variantAttributes: [
      'atributos',
      'variant_attributes',
      'multi_atributos',
      'atributos_variante',
    ],
    CatalogImportField.hasWarranty: [
      'garantia',
      'warranty',
      'has_warranty',
    ],
    CatalogImportField.isActive: [
      'activo',
      'is_active',
      'visible',
      'visibilidad',
      'publicado',
      'pausado',
    ],
    CatalogImportField.usdPaymentDiscountPct: [
      'descuento_usd',
      'usd_discount',
      'descuento_pago',
      'dto_usd',
    ],
    CatalogImportField.volumeTiersJson: [
      'tramos',
      'volume_tiers',
      'tramos_volumen',
    ],
  };

  static final _optionalSuffix = RegExp(r'_opcional$');
  static final _ambiguousStock =
      RegExp(r'(^|_)(pedido|solicitad[ao]s?|orden|reservad[ao]s?)(_|$)');
  static final _offerPrice =
      RegExp(r'(^|_)(oferta|promo|promocion|descuento)(_|$)');
  static final _secondaryCode =
      RegExp(r'(^|_)(barras|auxiliar|gtin|ean|upc|pedido|orden)(_|$)');

  /// Devuelve mapa `field.key` → nombre de columna sugerido (o null).
  static Map<String, String?> suggestAll(List<String> headers) {
    final used = <String>{};
    final out = <String, String?>{};
    final normalized = headers
        .map((header) => (
              header: header,
              key: _normalize(header).replaceFirst(_optionalSuffix, '')
            ))
        .where((entry) => entry.key.isNotEmpty)
        .toList();

    for (final exact in [true, false]) {
      for (final field in CatalogImportField.values) {
        if (out.containsKey(field.key)) continue;
        final guess = _guessOne(field, normalized, used, exact: exact);
        if (guess != null) {
          used.add(guess);
          out[field.key] = guess;
        }
      }
    }
    return out;
  }

  static String? _guessOne(
    CatalogImportField field,
    List<({String header, String key})> normalized,
    Set<String> used, {
    required bool exact,
  }) {
    final patterns = _patterns[field] ?? const [];
    for (final pattern in patterns) {
      for (final entry in normalized) {
        if (used.contains(entry.header)) continue;
        if (field == CatalogImportField.stock &&
            (_looksLikeMinOrderQty(entry.key) ||
                _ambiguousStock.hasMatch(entry.key))) {
          continue;
        }
        if ((field == CatalogImportField.sku ||
                field == CatalogImportField.name) &&
            _looksLikeParentSku(entry.key)) {
          continue;
        }
        if (field == CatalogImportField.priceUsd &&
            _offerPrice.hasMatch(entry.key)) {
          continue;
        }
        if (field == CatalogImportField.sku &&
            _secondaryCode.hasMatch(entry.key)) continue;
        if (exact ? entry.key == pattern : _matchesPrefix(entry.key, pattern)) {
          return entry.header;
        }
      }
    }
    return null;
  }

  static bool _matchesPrefix(String key, String pattern) {
    const exactOnly = {'ref', 'item', 'art', 'part', 'exist', 'sale', 'promo'};
    return !exactOnly.contains(pattern) && key.startsWith('${pattern}_');
  }

  static int headerScore(List<String> cells) {
    final fields = suggestAll(cells);
    final required = catalogImportRequiredFields
        .where((field) => fields.containsKey(field.key))
        .length;
    final hasSku = fields.containsKey(CatalogImportField.sku.key);
    final hasName = fields.containsKey(CatalogImportField.name.key);
    return required >= 2 && (hasSku || hasName) ? required : 0;
  }

  static bool _looksLikeParentSku(String normalizedHeader) {
    return normalizedHeader.contains('parent') ||
        normalizedHeader.contains('padre');
  }

  static bool _looksLikeMinOrderQty(String normalizedHeader) {
    return normalizedHeader.contains('minima') ||
        normalizedHeader.contains('minimo') ||
        normalizedHeader.contains('min_order') ||
        normalizedHeader.contains('moq') ||
        normalizedHeader.contains('pedido_min');
  }

  static String _normalize(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAllMapped(RegExp('[áéíóúüñ]'), (match) {
          const accents = 'áéíóúüñ';
          return 'aeiouun'[accents.indexOf(match[0]!)];
        })
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
