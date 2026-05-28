/// Tramos E3: tasa de comisión según volumen mensual USD del importador.
class CommissionVolumeTier {
  const CommissionVolumeTier({
    required this.minMonthlySalesUsd,
    required this.ratePct,
  });

  final double minMonthlySalesUsd;

  /// Fracción 0.05 = 5 %.
  final double ratePct;

  double get ratePercentDisplay => ratePct * 100;

  Map<String, dynamic> toJson() => {
        'min_monthly_sales_usd': minMonthlySalesUsd,
        'rate_pct': ratePct,
      };

  static CommissionVolumeTier? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final min = _asDouble(m['min_monthly_sales_usd']);
    final rate = _asDouble(m['rate_pct']);
    if (min == null || rate == null) return null;
    return CommissionVolumeTier(
      minMonthlySalesUsd: min,
      ratePct: rate,
    );
  }

  static double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }
}

List<CommissionVolumeTier> parseCommissionVolumeTiers(dynamic raw) {
  if (raw is! List) return [];
  final tiers = <CommissionVolumeTier>[];
  for (final e in raw) {
    final t = CommissionVolumeTier.fromJson(e);
    if (t != null) tiers.add(t);
  }
  tiers.sort((a, b) => a.minMonthlySalesUsd.compareTo(b.minMonthlySalesUsd));
  return tiers;
}

String commissionVolumeTiersSummaryEs(List<CommissionVolumeTier> tiers) {
  if (tiers.isEmpty) return 'Sin tramos (usa tasa global).';
  return tiers
      .map(
        (t) =>
            '≥ USD ${t.minMonthlySalesUsd.toStringAsFixed(0)} → '
            '${t.ratePercentDisplay.toStringAsFixed(2)} %',
      )
      .join(' · ');
}

/// Tramo activo para un volumen (misma lógica que el RPC SQL).
CommissionVolumeTier? activeCommissionVolumeTier(
  List<CommissionVolumeTier> tiers,
  double volumeUsd,
) {
  if (tiers.isEmpty) return null;
  CommissionVolumeTier? picked;
  for (final t in tiers) {
    if (volumeUsd >= t.minMonthlySalesUsd) {
      if (picked == null || t.minMonthlySalesUsd >= picked.minMonthlySalesUsd) {
        picked = t;
      }
    }
  }
  return picked;
}

/// Etiqueta corta: volumen → tramo → % efectivo.
String importerCommissionVolumeSummaryEs(
  double volumeUsd,
  double effectiveRatePct, {
  double? tierMinMonthlySalesUsd,
  double? overrideRatePct,
}) {
  final vol = 'USD ${volumeUsd.toStringAsFixed(2)}';
  final pct = '${(effectiveRatePct * 100).toStringAsFixed(2)} %';
  final override = overrideRatePct;
  if (override != null) {
    return '$vol · Tasa fija ${(override * 100).toStringAsFixed(2)} % (override)';
  }
  final min = tierMinMonthlySalesUsd;
  if (min != null) {
    return '$vol · Tramo ≥ USD ${min.toStringAsFixed(0)} → $pct';
  }
  return '$vol · Tramo actual → $pct';
}
