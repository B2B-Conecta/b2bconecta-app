import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/payments/document_type_preference.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';

/// Resumen gerencial estático (solo lectura) de Encomiendas.
class ExecutiveSummaryStaticCards extends StatelessWidget {
  const ExecutiveSummaryStaticCards({
    super.key,
    required this.orders,
  });

  final List<TransactionRequestModel> orders;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    if (orders.isEmpty) {
      return Text(
        'Sin resultados con los filtros actuales.',
        style: TextStyle(color: theme.textSecondary, fontSize: 13),
      );
    }

    final totalRef = orders.fold<double>(0, (s, r) => s + r.precioTotal);
    double? totalBs;
    var hasBs = false;
    var bsSum = 0.0;
    double? bcvRate;
    for (final r in orders) {
      final bs = r.precioTotalBsUi;
      if (bs != null) {
        hasBs = true;
        bsSum += bs;
      }
      bcvRate ??= r.tasaBcvAplicada ?? r.tasaBcvSnapshot;
    }
    if (hasBs) totalBs = bsSum;

    final conFactura = orders.where((r) => r.hasProveedorFactura).length;
    final pagosOk = orders
        .where(
          (r) => r.pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado,
        )
        .length;
    final entregados = orders
        .where((r) => r.status == TransactionRequestStatus.entregado)
        .length;
    final prefNota = orders
        .where(
          (r) =>
              r.documentTypePreference == DocumentTypePreference.notaEntrega,
        )
        .length;
    final prefFiscal = orders
        .where(
          (r) =>
              r.documentTypePreference ==
              DocumentTypePreference.facturaFiscal,
        )
        .length;
    final prefPend = orders
        .where(
          (r) =>
              r.documentTypePreference == null ||
              r.documentTypePreference!.trim().isEmpty,
        )
        .length;

    final cards = <_StaticKpi>[
      _StaticKpi(
        label: 'Pedidos',
        value: '${orders.length}',
        glyph: LucideGlyph.package,
      ),
      _StaticKpi(
        label: 'Total REF / USD',
        value: totalRef.toStringAsFixed(2),
        subtitle: totalBs == null
            ? null
            : bcvRate == null
                ? formatVesAmount(totalBs)
                : '${formatVesAmount(totalBs)} · BCV ${bcvRate.toStringAsFixed(2)}',
        glyph: LucideGlyph.dollarSign,
      ),
      _StaticKpi(
        label: 'Con factura',
        value: '$conFactura',
        glyph: LucideGlyph.fileText,
      ),
      _StaticKpi(
        label: 'Pagos OK',
        value: '$pagosOk',
        glyph: LucideGlyph.circleCheck,
      ),
      _StaticKpi(
        label: 'Entregados',
        value: '$entregados',
        glyph: LucideGlyph.packageCheck,
      ),
      _StaticKpi(
        label: 'Nota / Fiscal / Pend.',
        value: '$prefNota / $prefFiscal / $prefPend',
        glyph: LucideGlyph.scanLine,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final card in cards) _StaticKpiCard(theme: theme, kpi: card),
      ],
    );
  }
}

/// Alias de compatibilidad.
typedef ExecutiveSummaryCards = ExecutiveSummaryStaticCards;

class _StaticKpi {
  const _StaticKpi({
    required this.label,
    required this.value,
    required this.glyph,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
  final LucideGlyph glyph;
}

class _StaticKpiCard extends StatelessWidget {
  const _StaticKpiCard({required this.theme, required this.kpi});

  final B2BThemeExtension theme;
  final _StaticKpi kpi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.brandContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: LucideIcon(kpi.glyph, size: 16, color: theme.brand),
          ),
          const SizedBox(height: 10),
          Text(
            kpi.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kpi.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
              height: 1.25,
            ),
          ),
          if (kpi.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              kpi.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.textMuted,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
