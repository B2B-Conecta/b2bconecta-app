import 'catalog_sort_mode.dart';

/// Estado editable del panel de filtros del catálogo aliado.
class AliadoCatalogFiltersDraft {
  const AliadoCatalogFiltersDraft({
    required this.categoryLabel,
    required this.importerIds,
    required this.ownerEstado,
    required this.ownerCiudad,
    required this.minPrice,
    required this.maxPrice,
    this.sortMode = CatalogSortMode.recommended,
    this.minOwnerRatingAvg,
    this.minOwnerRatingCount,
    this.onlyWithCommercialDiscount = false,
  });

  final String categoryLabel;
  final Set<String> importerIds;
  final String ownerEstado;
  final String ownerCiudad;
  final String minPrice;
  final String maxPrice;
  final CatalogSortMode sortMode;
  final double? minOwnerRatingAvg;
  final int? minOwnerRatingCount;
  final bool onlyWithCommercialDiscount;

  bool get hasCategoryFilter => categoryLabel != 'Todos';

  bool get hasCommercialDiscountFilter => onlyWithCommercialDiscount;

  bool get hasImporterFilter => importerIds.isNotEmpty;

  bool get hasLocationFilter =>
      ownerEstado.trim().isNotEmpty || ownerCiudad.trim().isNotEmpty;

  bool get hasPriceFilter =>
      minPrice.trim().isNotEmpty || maxPrice.trim().isNotEmpty;

  bool get hasReputationFilter =>
      (minOwnerRatingAvg != null && minOwnerRatingAvg! > 0) ||
      (minOwnerRatingCount != null && minOwnerRatingCount! > 0);

  bool get hasNonDefaultSort => sortMode != CatalogSortMode.recommended;

  /// Filtros del panel (excluye texto de búsqueda principal).
  bool get hasAnyPanelFilter =>
      hasCategoryFilter ||
      hasImporterFilter ||
      hasLocationFilter ||
      hasPriceFilter ||
      hasReputationFilter ||
      hasCommercialDiscountFilter ||
      hasNonDefaultSort;

  int get activePanelFilterCount {
    var n = 0;
    if (hasCategoryFilter) n++;
    if (hasImporterFilter) n++;
    if (hasLocationFilter) {
      if (ownerEstado.trim().isNotEmpty) n++;
      if (ownerCiudad.trim().isNotEmpty) n++;
    }
    if (hasPriceFilter) {
      if (minPrice.trim().isNotEmpty) n++;
      if (maxPrice.trim().isNotEmpty) n++;
    }
    if (hasReputationFilter) {
      if (minOwnerRatingAvg != null && minOwnerRatingAvg! > 0) n++;
      if (minOwnerRatingCount != null && minOwnerRatingCount! > 0) n++;
    }
    if (hasCommercialDiscountFilter) n++;
    if (hasNonDefaultSort) n++;
    return n;
  }
}
