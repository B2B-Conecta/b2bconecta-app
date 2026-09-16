/// Modo de orden del catálogo aliado (E2.2).
enum CatalogSortMode {
  /// Categoría A–Z, y nombre A–Z dentro de cada una (default).
  category,

  /// Boost E1.1 → reputación rolling E2.1.
  recommended,

  /// Distancia al punto de referencia (GPS aliado).
  nearest,

  /// Reputación rolling primero; boost como desempate.
  reputation;

  static const CatalogSortMode defaultMode = category;
}

extension CatalogSortModeLabel on CatalogSortMode {
  String get labelEs {
    switch (this) {
      case CatalogSortMode.category:
        return 'Categoría (A–Z)';
      case CatalogSortMode.recommended:
        return 'Recomendado';
      case CatalogSortMode.nearest:
        return 'Más cercanos';
      case CatalogSortMode.reputation:
        return 'Mejor reputación';
    }
  }
}
