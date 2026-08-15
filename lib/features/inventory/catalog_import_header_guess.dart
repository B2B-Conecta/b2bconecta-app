import 'catalog_import/catalog_import_field.dart';

/// Sugiere columnas del archivo ERP para cada campo B2B Conecta.
class CatalogImportHeaderGuess {
  CatalogImportHeaderGuess._();

  static final _patterns = <CatalogImportField, List<String>>{
    CatalogImportField.sku: [
      'sku',
      'cod_art',
      'codigo',
      'cod',
      'articulo',
      'art',
      'ref',
      'item',
      'part',
    ],
    CatalogImportField.name: [
      'nombre',
      'name',
      'descripcion',
      'description',
      'desc',
      'producto',
      'titulo',
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
      'precio_mayor',
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
      'exist',
      'qty',
      'cantidad',
      'inventario',
      'disponible',
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
    CatalogImportField.hasWarranty: [
      'garantia',
      'warranty',
      'has_warranty',
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

  /// Devuelve mapa `field.key` → nombre de columna sugerido (o null).
  static Map<String, String?> suggestAll(List<String> headers) {
    final used = <String>{};
    final out = <String, String?>{};

    for (final field in CatalogImportField.values) {
      final guess = _guessOne(field, headers, used);
      if (guess != null) {
        used.add(guess);
        out[field.key] = guess;
      }
    }
    return out;
  }

  static String? _guessOne(
    CatalogImportField field,
    List<String> headers,
    Set<String> used,
  ) {
    final patterns = _patterns[field] ?? const [];
    final normalized = headers
        .map((h) => (header: h, key: _normalize(h)))
        .where((e) => !used.contains(e.header))
        .toList();

    for (final pattern in patterns) {
      for (final entry in normalized) {
        if (entry.key == pattern || entry.key.contains(pattern)) {
          return entry.header;
        }
      }
    }
    return null;
  }

  static String _normalize(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
