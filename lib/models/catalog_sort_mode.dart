/// Modo de orden del catálogo aliado (E2.2).
enum CatalogSortMode {
  /// Boost E1.1 → reputación rolling E2.1.
  recommended,

  /// Distancia al punto de referencia (GPS aliado).
  nearest,

  /// Reputación rolling primero; boost como desempate.
  reputation,
}

extension CatalogSortModeLabel on CatalogSortMode {
  String get labelEs {
    switch (this) {
      case CatalogSortMode.recommended:
        return 'Recomendado';
      case CatalogSortMode.nearest:
        return 'Más cercanos';
      case CatalogSortMode.reputation:
        return 'Mejor reputación';
    }
  }
}
