import 'catalog_sort_mode.dart';

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
    this.sortMode = CatalogSortMode.recommended,
    this.sortReferenceLat,
    this.sortReferenceLng,
    this.minOwnerRatingAvg,
    this.minOwnerRatingCount,
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

  /// Orden de resultados (E2.2): recomendado, cercanía o reputación.
  final CatalogSortMode sortMode;

  /// Punto de referencia para [CatalogSortMode.nearest].
  final double? sortReferenceLat;
  final double? sortReferenceLng;

  /// Umbral mínimo sobre `profiles.rating_avg_received_rolling100` (E2.2).
  final double? minOwnerRatingAvg;

  /// Umbral mínimo sobre `profiles.rating_count_received_rolling100` (E2.2).
  final int? minOwnerRatingCount;

  static const CatalogFilters empty = CatalogFilters(onlyActiveProducts: true);

  bool get sortByDistanceFromReference =>
      sortMode == CatalogSortMode.nearest &&
      sortReferenceLat != null &&
      sortReferenceLng != null &&
      !sortReferenceLat!.isNaN &&
      !sortReferenceLng!.isNaN;

  bool get hasReputationThreshold =>
      (minOwnerRatingAvg != null && minOwnerRatingAvg! > 0) ||
      (minOwnerRatingCount != null && minOwnerRatingCount! > 0);

  bool get hasAnyFilter {
    final q = searchQuery?.trim();
    return (q != null && q.isNotEmpty) ||
        ownerIds.isNotEmpty ||
        (ownerId != null && ownerId!.trim().isNotEmpty) ||
        (ownerEstado != null && ownerEstado!.trim().isNotEmpty) ||
        (ownerCiudad != null && ownerCiudad!.trim().isNotEmpty) ||
        minPrice != null ||
        maxPrice != null ||
        hasReputationThreshold ||
        sortMode != CatalogSortMode.recommended;
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
    CatalogSortMode? sortMode,
    double? sortReferenceLat,
    double? sortReferenceLng,
    double? minOwnerRatingAvg,
    int? minOwnerRatingCount,
    bool clearSortReference = false,
    bool clearMinOwnerRatingAvg = false,
    bool clearMinOwnerRatingCount = false,
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
      sortMode: sortMode ?? this.sortMode,
      sortReferenceLat:
          clearSortReference ? null : (sortReferenceLat ?? this.sortReferenceLat),
      sortReferenceLng:
          clearSortReference ? null : (sortReferenceLng ?? this.sortReferenceLng),
      minOwnerRatingAvg: clearMinOwnerRatingAvg
          ? null
          : (minOwnerRatingAvg ?? this.minOwnerRatingAvg),
      minOwnerRatingCount: clearMinOwnerRatingCount
          ? null
          : (minOwnerRatingCount ?? this.minOwnerRatingCount),
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
