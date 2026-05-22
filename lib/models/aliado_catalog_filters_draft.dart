/// Estado editable del panel de filtros del catálogo aliado.
class AliadoCatalogFiltersDraft {
  const AliadoCatalogFiltersDraft({
    required this.categoryLabel,
    required this.importerIds,
    required this.ownerEstado,
    required this.ownerCiudad,
    required this.minPrice,
    required this.maxPrice,
    required this.closestToMe,
  });

  final String categoryLabel;
  final Set<String> importerIds;
  final String ownerEstado;
  final String ownerCiudad;
  final String minPrice;
  final String maxPrice;
  final bool closestToMe;

  bool get hasCategoryFilter => categoryLabel != 'Todos';

  bool get hasImporterFilter => importerIds.isNotEmpty;

  bool get hasLocationFilter =>
      ownerEstado.trim().isNotEmpty || ownerCiudad.trim().isNotEmpty;

  bool get hasPriceFilter =>
      minPrice.trim().isNotEmpty || maxPrice.trim().isNotEmpty;

  /// Filtros del panel (excluye texto de búsqueda principal).
  bool get hasAnyPanelFilter =>
      hasCategoryFilter ||
      hasImporterFilter ||
      hasLocationFilter ||
      hasPriceFilter ||
      closestToMe;

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
    if (closestToMe) n++;
    return n;
  }
}
