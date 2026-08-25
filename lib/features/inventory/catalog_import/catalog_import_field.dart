/// Campos core de `products` soportados en la carga masiva flexible.
enum CatalogImportField {
  sku,
  name,
  description,
  priceUsd,
  salePriceUsd,
  stock,
  category,
  compatibility,
  imageUrl,
  hasWarranty,
  usdPaymentDiscountPct,
  volumeTiersJson,
}

extension CatalogImportFieldX on CatalogImportField {
  String get key => switch (this) {
        CatalogImportField.sku => 'sku',
        CatalogImportField.name => 'name',
        CatalogImportField.description => 'description',
        CatalogImportField.priceUsd => 'price_usd',
        CatalogImportField.salePriceUsd => 'sale_price_usd',
        CatalogImportField.stock => 'stock',
        CatalogImportField.category => 'category',
        CatalogImportField.compatibility => 'compatibility',
        CatalogImportField.imageUrl => 'image_url',
        CatalogImportField.hasWarranty => 'has_warranty',
        CatalogImportField.usdPaymentDiscountPct => 'usd_payment_discount_pct',
        CatalogImportField.volumeTiersJson => 'volume_tiers_json',
      };

  bool get isRequired => switch (this) {
        CatalogImportField.sku ||
        CatalogImportField.name ||
        CatalogImportField.priceUsd =>
          true,
        _ => false,
      };

  String get label => switch (this) {
        CatalogImportField.sku => 'SKU / Código',
        CatalogImportField.name => 'Nombre',
        CatalogImportField.description => 'Descripción',
        CatalogImportField.priceUsd => 'Precio mayorista (USD)',
        CatalogImportField.salePriceUsd => 'Precio oferta (USD)',
        CatalogImportField.stock => 'Stock',
        CatalogImportField.category => 'Categoría',
        CatalogImportField.compatibility => 'Compatibilidad',
        CatalogImportField.imageUrl => 'URL imagen',
        CatalogImportField.hasWarranty => 'Garantía',
        CatalogImportField.usdPaymentDiscountPct => 'Descuento pago USD (%)',
        CatalogImportField.volumeTiersJson => 'Tramos volumen (JSON)',
      };

  static CatalogImportField? fromKey(String raw) {
    final k = raw.trim().toLowerCase();
    for (final f in CatalogImportField.values) {
      if (f.key == k) return f;
    }
    return null;
  }
}

/// Campos obligatorios que el UI debe mapear antes de importar.
const catalogImportRequiredFields = [
  CatalogImportField.sku,
  CatalogImportField.name,
  CatalogImportField.priceUsd,
];
