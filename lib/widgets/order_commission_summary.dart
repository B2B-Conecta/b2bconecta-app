import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_order_grouping.dart';
import '../utils/app_date_format.dart';

double lineCommissionUsd(TransactionRequestModel r) =>
    r.comisionDevengadaUsd ?? r.comisionEstimadaUsd;

double chunkCommissionUsd(List<TransactionRequestModel> chunk) =>
    chunk.fold<double>(0, (s, r) => s + lineCommissionUsd(r));

/// Líneas en las que aplica mostrar comisión (post-aprobación).
List<TransactionRequestModel> orderLinesEligibleForCommission(
  Iterable<TransactionRequestModel> lines,
) {
  return lines
      .where(
        (r) =>
            r.status != TransactionRequestStatus.pendiente &&
            r.status != TransactionRequestStatus.rechazado,
      )
      .toList();
}

/// Comisión MotoLink unificada: un total por pedido/proveedor y desglose opcional.
class OrderCommissionSummary extends StatelessWidget {
  const OrderCommissionSummary({
    super.key,
    required this.lines,
    /// Solo la comisión de un proveedor dentro de un carrito (panel admin por chip).
    this.importerChunk,
  });

  final List<TransactionRequestModel> lines;
  final List<TransactionRequestModel>? importerChunk;

  @override
  Widget build(BuildContext context) {
    final eligible = orderLinesEligibleForCommission(lines);
    if (eligible.isEmpty) return const SizedBox.shrink();

    if (importerChunk != null && importerChunk!.isNotEmpty) {
      final chunk = orderLinesEligibleForCommission(importerChunk!);
      if (chunk.isEmpty) return const SizedBox.shrink();
      return _CommissionBox(
        title: 'Comisión MotoLink (este proveedor)',
        lines: chunk,
        totalUsd: chunkCommissionUsd(chunk),
        todasDevengadas: chunk.every((r) => r.comisionDevengada),
        rateSnapshot: chunk.first.commissionRateSnapshot,
        breakdownMode:
            chunk.length > 1 ? _BreakdownMode.linesInChunk : _BreakdownMode.none,
      );
    }

    final totalUsd = chunkCommissionUsd(eligible);
    final todasDevengadas = eligible.every((r) => r.comisionDevengada);
    final chunks = groupCheckoutLinesByImportador(eligible);
    final byImporter = chunks.length > 1;

    return _CommissionBox(
      title: eligible.length > 1
          ? 'Comisión MotoLink (pedido)'
          : 'Comisión MotoLink',
      lines: eligible,
      totalUsd: totalUsd,
      todasDevengadas: todasDevengadas,
      rateSnapshot: eligible.first.commissionRateSnapshot,
      breakdownMode: byImporter
          ? _BreakdownMode.byImporter
          : (eligible.length > 1
              ? _BreakdownMode.linesInChunk
              : _BreakdownMode.none),
      importerChunks: byImporter ? chunks : null,
    );
  }
}

/// Alias histórico (admin carrito).
typedef AdminCheckoutGroupCommissionSummary = OrderCommissionSummary;

enum _BreakdownMode { none, linesInChunk, byImporter }

class _CommissionBox extends StatelessWidget {
  const _CommissionBox({
    required this.title,
    required this.lines,
    required this.totalUsd,
    required this.todasDevengadas,
    required this.rateSnapshot,
    required this.breakdownMode,
    this.importerChunks,
  });

  final String title;
  final List<TransactionRequestModel> lines;
  final double totalUsd;
  final bool todasDevengadas;
  final double rateSnapshot;
  final _BreakdownMode breakdownMode;
  final List<List<TransactionRequestModel>>? importerChunks;

  @override
  Widget build(BuildContext context) {
    final pct = (rateSnapshot * 100).toStringAsFixed(2);
    final latestDevengadaAt = lines
        .map((r) => r.comisionDevengadaAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) {
      if (a == null) return b;
      return b.isAfter(a) ? b : a;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: Colors.teal.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tasa $pct % · '
            '${todasDevengadas ? 'Devengada' : 'Pendiente de recibir'}: '
            'USD ${totalUsd.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          if (todasDevengadas && latestDevengadaAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Devengada: ${formatEsShortDateTime(latestDevengadaAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
          if (breakdownMode != _BreakdownMode.none) ...[
            const SizedBox(height: 8),
            Text(
              'Desglose',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            if (breakdownMode == _BreakdownMode.byImporter &&
                importerChunks != null)
              ...importerChunks!.map(_importerBreakdownLine)
            else
              ...lines.map((r) => _productLineBreakdown(r)),
          ],
        ],
      ),
    );
  }

  Widget _importerBreakdownLine(List<TransactionRequestModel> chunk) {
    final name = chunk.first.ownerBusinessName?.trim() ?? 'Proveedor';
    final sub = chunkCommissionUsd(chunk);
    final devengada = chunk.every((r) => r.comisionDevengada);
    final at = chunk
        .map((r) => r.comisionDevengadaAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) {
      if (a == null) return b;
      return b.isAfter(a) ? b : a;
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '· $name: USD ${sub.toStringAsFixed(2)}'
            '${devengada && at != null ? ' · ${formatEsShortDateTime(at)}' : ''}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          if (chunk.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: chunk
                    .map((r) => _productLineBreakdown(r, nested: true))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _productLineBreakdown(TransactionRequestModel r, {bool nested = false}) {
    final monto = lineCommissionUsd(r);
    final prefix = nested ? '  ' : '· ';
    var text =
        '$prefix${r.productName ?? 'Línea'}: USD ${monto.toStringAsFixed(2)}';
    if (r.comisionDevengada && r.comisionDevengadaAt != null) {
      text += ' · ${formatEsShortDateTime(r.comisionDevengadaAt)}';
    }
    if (r.commissionSettlementId != null) {
      text += ' · Corte ${r.commissionSettlementId!.substring(0, 8)}…';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800),
      ),
    );
  }
}
