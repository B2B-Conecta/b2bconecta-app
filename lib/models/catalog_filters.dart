/// Filtros del catálogo de repuestos (consultas a `products`).
class CatalogFilters {
  const CatalogFilters({
    this.searchQuery,
    this.ownerId,
    this.ownerIds = const [],
    this.ownerEstado,
    this.ownerCiudad,
    this.minPrice,
    this.maxPrice,
    this.onlyActiveProducts = true,
    this.sortReferenceLat,
    this.sortReferenceLng,
  });

  /// Texto libre: nombre del repuesto y ubicación del importador (`profiles.estado` / `ciudad`).
  final String? searchQuery;

  /// `profiles.id` del importador; `null` = todos. Preferir [ownerIds] para varios.
  final String? ownerId;

  /// IDs de importadores a incluir; vacío = sin filtro por proveedor.
  final List<String> ownerIds;

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

  /// Si ambos están definidos, el catálogo aliado se ordena por distancia creciente
  /// (Haversine) respecto a este punto (p. ej. GPS del aliado).
  final double? sortReferenceLat;
  final double? sortReferenceLng;

  static const CatalogFilters empty = CatalogFilters(onlyActiveProducts: true);

  bool get sortByDistanceFromReference =>
      sortReferenceLat != null &&
      sortReferenceLng != null &&
      !sortReferenceLat!.isNaN &&
      !sortReferenceLng!.isNaN;

  bool get hasAnyFilter {
    final q = searchQuery?.trim();
    return (q != null && q.isNotEmpty) ||
        ownerIds.isNotEmpty ||
        (ownerId != null && ownerId!.trim().isNotEmpty) ||
        (ownerEstado != null && ownerEstado!.trim().isNotEmpty) ||
        (ownerCiudad != null && ownerCiudad!.trim().isNotEmpty) ||
        minPrice != null ||
        maxPrice != null;
  }

  List<String> get effectiveOwnerIds {
    if (ownerIds.isNotEmpty) {
      return ownerIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    final single = ownerId?.trim();
    if (single != null && single.isNotEmpty) return [single];
    return const [];
  }

  CatalogFilters copyWith({
    String? searchQuery,
    String? ownerId,
    List<String>? ownerIds,
    String? ownerEstado,
    String? ownerCiudad,
    double? minPrice,
    double? maxPrice,
    bool? onlyActiveProducts,
    double? sortReferenceLat,
    double? sortReferenceLng,
    bool clearSortReference = false,
  }) {
    return CatalogFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      ownerId: ownerId ?? this.ownerId,
      ownerIds: ownerIds ?? this.ownerIds,
      ownerEstado: ownerEstado ?? this.ownerEstado,
      ownerCiudad: ownerCiudad ?? this.ownerCiudad,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      onlyActiveProducts: onlyActiveProducts ?? this.onlyActiveProducts,
      sortReferenceLat:
          clearSortReference ? null : (sortReferenceLat ?? this.sortReferenceLat),
      sortReferenceLng:
          clearSortReference ? null : (sortReferenceLng ?? this.sortReferenceLng),
    );
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
