/// Filtros del catálogo de repuestos (consultas a `products`).
class CatalogFilters {
  const CatalogFilters({
    this.searchQuery,
    this.ownerId,
    this.ownerEstado,
    this.ownerCiudad,
    this.minPrice,
    this.maxPrice,
    this.onlyActiveProducts = true,
  });

  /// Texto libre: nombre del repuesto y ubicación del importador (`profiles.estado` / `ciudad`).
  final String? searchQuery;

  /// `profiles.id` del importador; `null` = todos.
  final String? ownerId;

  /// Filtro por estado del importador (`profiles.estado`, ilike).
  final String? ownerEstado;

  /// Filtro por ciudad del importador (`profiles.ciudad`, ilike).
  final String? ownerCiudad;

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
        (ownerEstado != null && ownerEstado!.trim().isNotEmpty) ||
        (ownerCiudad != null && ownerCiudad!.trim().isNotEmpty) ||
        minPrice != null ||
        maxPrice != null;
  }
}

/// Opción para el desplegable de importador (`profiles`).
class ImporterOption {
  const ImporterOption({
    required this.id,
    required this.businessName,
    this.estado,
    this.ciudad,
  });

  final String id;
  final String businessName;
  final String? estado;
  final String? ciudad;

  /// Línea corta para tooltip (ubicación del proveedor).
  String get ubicacionLine {
    final e = estado?.trim();
    final c = ciudad?.trim();
    if ((e == null || e.isEmpty) && (c == null || c.isEmpty)) {
      return 'Ubicación no indicada';
    }
    if (e != null && e.isNotEmpty && c != null && c.isNotEmpty) {
      return '$e · $c';
    }
    return e ?? c ?? '';
  }
}
