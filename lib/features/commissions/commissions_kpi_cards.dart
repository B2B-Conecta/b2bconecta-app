import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_fiscal.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_model.dart';

/// KPIs financieros del módulo Comisiones (REF/USD + equivalente BCV).
class CommissionsKpiCards extends StatelessWidget {
  const CommissionsKpiCards({
    super.key,
    required this.rows,
    this.tasaBcv,
  });

  final List<CommissionSettlementModel> rows;
  final double? tasaBcv;

  static ({double devengadas, double liquidadasMes, double pendiente})
      compute(List<CommissionSettlementModel> rows, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    var devengadas = 0.0;
    var liquidadasMes = 0.0;
    var pendiente = 0.0;
    for (final s in rows) {
      if (s.isAnulado) continue;
      devengadas += s.totalCobroUsd;
      if (s.isPagado) {
        final paid = s.paidAt;
        if (paid != null &&
            paid.year == clock.year &&
            paid.month == clock.month) {
          liquidadasMes += s.totalCobroUsd;
        }
      }
      if (s.isEmitido) {
        pendiente += s.totalCobroUsd;
      }
    }
    return (
      devengadas: devengadas,
      liquidadasMes: liquidadasMes,
      pendiente: pendiente,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final totals = compute(rows);
    final cards = <_KpiSpec>[
      _KpiSpec(
        label: 'Comisiones devengadas',
        usd: totals.devengadas,
        glyph: LucideGlyph.badgeDollarSign,
        accent: theme.brand,
      ),
      _KpiSpec(
        label: 'Liquidadas del mes',
        usd: totals.liquidadasMes,
        glyph: LucideGlyph.circleCheck,
        accent: theme.successFg,
      ),
      _KpiSpec(
        label: 'Corte pendiente',
        usd: totals.pendiente,
        glyph: LucideGlyph.clipboardCheck,
        accent: theme.brand,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 720;
        if (stack) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _KpiCard(spec: cards[i], tasaBcv: tasaBcv),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _KpiCard(spec: cards[i], tasaBcv: tasaBcv)),
            ],
          ],
        );
      },
    );
  }
}

class _KpiSpec {
  const _KpiSpec({
    required this.label,
    required this.usd,
    required this.glyph,
    required this.accent,
  });

  final String label;
  final double usd;
  final LucideGlyph glyph;
  final Color accent;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.spec, this.tasaBcv});

  final _KpiSpec spec;
  final double? tasaBcv;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final rate = tasaBcv;
    final bs = rate != null && rate > 0 ? spec.usd * rate : null;

    return Material(
      color: theme.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.brandContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: LucideIcon(spec.glyph, size: 18, color: spec.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'REF ${formatRefAmount(spec.usd)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bs == null
                        ? 'Bs — (sin tasa BCV)'
                        : formatBsLabel(bs),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
