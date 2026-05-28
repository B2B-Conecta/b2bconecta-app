/// Volumen mensual y tasa de comisión vigente (E3), desde RPC.
class ImporterCommissionVolumeContext {
  const ImporterCommissionVolumeContext({
    required this.importadorId,
    required this.volumeUsd,
    required this.effectiveRatePct,
    required this.tierRatePct,
    this.overrideRatePct,
    this.tierMinMonthlySalesUsd,
  });

  final String importadorId;
  final double volumeUsd;
  final double effectiveRatePct;
  final double tierRatePct;
  final double? overrideRatePct;
  final double? tierMinMonthlySalesUsd;

  bool get hasOverride => overrideRatePct != null;

  double get effectiveRatePercentDisplay => effectiveRatePct * 100;

  static ImporterCommissionVolumeContext? fromRpc(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['importador_id']?.toString();
    if (id == null || id.isEmpty) return null;
    final volume = _asDouble(m['volume_usd']);
    final effective = _asDouble(m['effective_rate_pct']);
    final tierRate = _asDouble(m['tier_rate_pct']);
    if (volume == null || effective == null || tierRate == null) return null;
    return ImporterCommissionVolumeContext(
      importadorId: id,
      volumeUsd: volume,
      effectiveRatePct: effective,
      tierRatePct: tierRate,
      overrideRatePct: _asDouble(m['override_rate_pct']),
      tierMinMonthlySalesUsd: _asDouble(m['tier_min_monthly_sales_usd']),
    );
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
