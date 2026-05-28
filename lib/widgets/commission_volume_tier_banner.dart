import 'package:flutter/material.dart';

import '../models/importer_commission_volume_context.dart';
import '../utils/commission_volume_tiers.dart';

/// Resumen E3: volumen del mes → tramo/tasa aplicable en checkout.
class CommissionVolumeTierBanner extends StatelessWidget {
  const CommissionVolumeTierBanner({
    super.key,
    required this.volumeContext,
    this.compact = false,
    this.title,
  });

  final ImporterCommissionVolumeContext volumeContext;
  final bool compact;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ctx = volumeContext;
    final summary = importerCommissionVolumeSummaryEs(
      ctx.volumeUsd,
      ctx.effectiveRatePct,
      tierMinMonthlySalesUsd: ctx.tierMinMonthlySalesUsd,
      overrideRatePct: ctx.overrideRatePct,
    );
    final accent = ctx.hasOverride ? Colors.deepPurple : Colors.teal;

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.stacked_line_chart, size: 18, color: accent.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: accent.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 20, color: accent.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title ?? 'Volumen del mes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: accent.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: accent.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ctx.hasOverride
                ? 'MotoLink aplicó una tasa fija en su perfil; no usan tramos por volumen.'
                : 'Pedidos entregados este mes definen el tramo. La tasa se fija al confirmar cada pedido.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: accent.shade900.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}
