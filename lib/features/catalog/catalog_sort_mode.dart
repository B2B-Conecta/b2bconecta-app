import 'package:flutter/material.dart';

/// Modo de orden del catálogo aliado.
enum CatalogSortMode {
  /// Categoría A–Z, y nombre A–Z dentro de cada una (default).
  category,

  /// Boost por actividad/pagos y reputación.
  recommended,

  /// Distancia al punto de referencia (GPS aliado).
  nearest,

  /// Primero proveedores con sello Destacado (admin, máx. 3).
  featured;

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
      case CatalogSortMode.featured:
        return 'Destacados';
    }
  }

  String get subtitleEs {
    switch (this) {
      case CatalogSortMode.category:
        return 'Agrupa por categoría y ordena A–Z dentro de cada una.';
      case CatalogSortMode.recommended:
        return 'Prioriza actividad reciente y reputación.';
      case CatalogSortMode.nearest:
        return 'Ordena por distancia a tu ubicación (GPS).';
      case CatalogSortMode.featured:
        return 'Primero proveedores con sello Destacado.';
    }
  }

  IconData get iconData {
    switch (this) {
      case CatalogSortMode.category:
        return Icons.sort_by_alpha_rounded;
      case CatalogSortMode.recommended:
        return Icons.auto_awesome_rounded;
      case CatalogSortMode.nearest:
        return Icons.near_me_rounded;
      case CatalogSortMode.featured:
        return Icons.star_rounded;
    }
  }
}
