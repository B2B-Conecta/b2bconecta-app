/// Filtros del catálogo de repuestos (consultas a `products`).
class CatalogFilters {
  const CatalogFilters({
    this.searchQuery,
    this.ownerId,
    this.minPrice,
    this.maxPrice,
    this.onlyActiveProducts = true,
  });

  /// Texto libre: coincide con `products.name` (ilike, sin distinguir mayúsculas).
  final String? searchQuery;

  /// `profiles.id` del importador; `null` = todos.
  final String? ownerId;

  /// Precio mínimo en USD (`price_usd`).
  final double? minPrice;

  /// Precio máximo en USD (`price_usd`).
  final double? maxPrice;

  /// Catálogo público (aliados): solo filas con `is_active = true`.
  /// Inventario del importador: `false` para incluir pausados.
  final bool onlyActiveProducts;

  static const CatalogFilters empty = CatalogFilters(onlyActiveProducts: true);

  bool get hasAnyFilter {
    final q = searchQuery?.trim();
    return (q != null && q.isNotEmpty) ||
        (ownerId != null && ownerId!.trim().isNotEmpty) ||
        minPrice != null ||
        maxPrice != null;
  }
}

/// Opción para el desplegable de importador (`profiles`).
class ImporterOption {
  const ImporterOption({
    required this.id,
    required this.businessName,
  });

  final String id;
  final String businessName;
}
