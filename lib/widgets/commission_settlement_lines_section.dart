import 'package:flutter/material.dart';

import '../models/commission_settlement_model.dart';
import '../services/supabase_service.dart';
import '../utils/commission_settlement_fiscal.dart';

/// Detalle informativo de ventas incluidas en un corte (admin e importador).
class CommissionSettlementLinesSection extends StatefulWidget {
  const CommissionSettlementLinesSection({
    super.key,
    required this.settlementId,
  });

  final String settlementId;

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
    _future = SupabaseService.fetchCommissionSettlementLines(widget.settlementId);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalle informativo de ventas (no comercial)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Monto total vendido en el período (referencia): '
              'USD ${totalVentas.toStringAsFixed(2)}. '
              'No forma parte del total a pagar de la factura de comisión.',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pedidos incluidos (${lines.length})',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            ...lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· ${l.productName ?? l.requestId.substring(0, 8)} — '
                  'venta USD ${l.precioTotalUsd.toStringAsFixed(2)}, '
                  'comisión USD ${l.comisionDevengadaUsd.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, height: 1.3),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
