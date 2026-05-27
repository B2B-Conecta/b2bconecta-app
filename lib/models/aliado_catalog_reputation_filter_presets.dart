/// Presets de filtros de reputación en catálogo aliado (E2.2).
class AliadoCatalogMinRatingPreset {
  const AliadoCatalogMinRatingPreset({
    required this.label,
    this.minAvg,
  });

  final String label;

  /// `null` = sin umbral de estrellas.
  final double? minAvg;
}

class AliadoCatalogMinRatingCountPreset {
  const AliadoCatalogMinRatingCountPreset({
    required this.label,
    this.minCount,
  });

  final String label;

  /// `null` = sin umbral de cantidad.
  final int? minCount;
}

const kAliadoCatalogMinRatingPresets = <AliadoCatalogMinRatingPreset>[
  AliadoCatalogMinRatingPreset(label: 'Sin mínimo'),
  AliadoCatalogMinRatingPreset(label: '≥ 3.0 ★', minAvg: 3.0),
  AliadoCatalogMinRatingPreset(label: '≥ 4.0 ★', minAvg: 4.0),
  AliadoCatalogMinRatingPreset(label: '≥ 4.5 ★', minAvg: 4.5),
];

const kAliadoCatalogMinRatingCountPresets = <AliadoCatalogMinRatingCountPreset>[
  AliadoCatalogMinRatingCountPreset(label: 'Sin mínimo'),
  AliadoCatalogMinRatingCountPreset(label: '≥ 3 valoraciones', minCount: 3),
  AliadoCatalogMinRatingCountPreset(label: '≥ 5 valoraciones', minCount: 5),
  AliadoCatalogMinRatingCountPreset(label: '≥ 10 valoraciones', minCount: 10),
];
