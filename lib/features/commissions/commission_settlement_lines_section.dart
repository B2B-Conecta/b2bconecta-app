import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

import 'commission_settlement_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'commission_settlement_fiscal.dart';

/// Detalle informativo de ventas incluidas en un corte (admin e importador).
class CommissionSettlementLinesSection extends StatefulWidget {
  const CommissionSettlementLinesSection({
    super.key,
    required this.settlementId,
    this.initiallyCollapsed = false,
  });

  final String settlementId;
  final bool initiallyCollapsed;

  @override
  State<CommissionSettlementLinesSection> createState() =>
      _CommissionSettlementLinesSectionState();
}

class _CommissionSettlementLinesSectionState
    extends State<CommissionSettlementLinesSection> {
  late Future<List<CommissionSettlementLineModel>> _future;

  @override
  void initState() {
    super.initState();
    _future =
        SupabaseService.fetchCommissionSettlementLines(widget.settlementId);
  }

  @override
  void didUpdateWidget(covariant CommissionSettlementLinesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settlementId != widget.settlementId) {
      _future =
          SupabaseService.fetchCommissionSettlementLines(widget.settlementId);
    }
  }

  String _name(CommissionSettlementLineModel line) {
    final name = line.productName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = line.requestId;
    return 'Pedido #${id.length > 8 ? id.substring(0, 8) : id}';
  }

  Widget _money(String label, double amount) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 3),
        Text('USD ${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]);

  Widget _line(CommissionSettlementLineModel line, bool desktop) {
    final name =
        Text(_name(line), style: const TextStyle(fontSize: 13, height: 1.4));
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: desktop
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: name),
                const SizedBox(width: 16),
                Expanded(child: _money('Venta', line.precioTotalUsd)),
                const SizedBox(width: 12),
                Expanded(child: _money('Comisión', line.comisionDevengadaUsd)),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                name,
                const SizedBox(height: 8),
                Wrap(spacing: 24, runSpacing: 8, children: [
                  _money('Venta', line.precioTotalUsd),
                  _money('Comisión', line.comisionDevengadaUsd),
                ]),
              ]));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommissionSettlementLineModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 3),
          );
        }
        if (snap.hasError) {
          return Text(
            'No se pudo cargar el detalle: ${snap.error}',
            style: const TextStyle(fontSize: 11, color: Colors.red),
          );
        }
        final lines = snap.data ?? const [];
        if (lines.isEmpty) {
          return const Text(
            'Sin líneas en este corte.',
            style: TextStyle(fontSize: 12),
          );
        }
        final totalVentas =
            CommissionSettlementFiscal.totalVentasInformativoUsd(lines);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ventas relacionadas · USD ${totalVentas.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Valor de las ventas utilizadas para calcular la comisión. '
              'Este importe es informativo y no se suma al cobro.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              key: ValueKey('settlement-lines-${widget.settlementId}'),
              initiallyExpanded: !widget.initiallyCollapsed,
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: EdgeInsets.zero,
              title: Text('Pedidos incluidos · ${lines.length}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              children: [
                LayoutBuilder(
                    builder: (context, constraints) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < lines.length; i++) ...[
                              if (i > 0)
                                Divider(
                                    height: 1, color: AppColors.borderSubtle),
                              _line(lines[i], constraints.maxWidth >= 650),
                            ],
                          ],
                        ))
              ],
            ),
          ],
        );
      },
    );
  }
}
