import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_order_grouping.dart';
import '../utils/app_date_format.dart';

double _lineCommissionUsd(TransactionRequestModel r) =>
    r.comisionDevengadaUsd ?? r.comisionEstimadaUsd;

double _chunkCommissionUsd(List<TransactionRequestModel> chunk) =>
    chunk.fold<double>(0, (s, r) => s + _lineCommissionUsd(r));

/// Comisión MotoLink: total del carrito o de un proveedor.
class AdminCheckoutGroupCommissionSummary extends StatelessWidget {
  const AdminCheckoutGroupCommissionSummary({
    super.key,
    required this.lines,
    /// Si se define, solo muestra la comisión de ese importador (panel por proveedor).
    this.importerChunk,
  });

  final List<TransactionRequestModel> lines;
  final List<TransactionRequestModel>? importerChunk;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    if (importerChunk != null && importerChunk!.isNotEmpty) {
      return _CommissionBox(
        title: 'Comisión MotoLink (este proveedor)',
        lines: importerChunk!,
        totalUsd: _chunkCommissionUsd(importerChunk!),
        todasDevengadas: importerChunk!.every((r) => r.comisionDevengada),
        rateSnapshot: importerChunk!.first.commissionRateSnapshot,
        breakdownMode: _BreakdownMode.linesInChunk,
      );
    }

    final totalUsd = _chunkCommissionUsd(lines);
    final todasDevengadas = lines.every((r) => r.comisionDevengada);
    final chunks = groupCheckoutLinesByImportador(lines);
    final byImporter = chunks.length > 1;

    return _CommissionBox(
      title: 'Comisión MotoLink (pedido)',
      lines: lines,
      totalUsd: totalUsd,
      todasDevengadas: todasDevengadas,
      rateSnapshot: lines.first.commissionRateSnapshot,
      breakdownMode: byImporter
          ? _BreakdownMode.byImporter
          : (lines.length > 1
              ? _BreakdownMode.linesInChunk
              : _BreakdownMode.none),
      importerChunks: byImporter ? chunks : null,
    );
  }
}

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
          if (breakdownMode != _BreakdownMode.none) ...[
            const SizedBox(height: 8),
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
    final sub = _chunkCommissionUsd(chunk);
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
                children: chunk.map((r) => _productLineBreakdown(r, nested: true)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _productLineBreakdown(TransactionRequestModel r, {bool nested = false}) {
    final monto = _lineCommissionUsd(r);
    final prefix = nested ? '  ' : '· ';
    var text =
        '$prefix${r.productName ?? 'Línea'}: USD ${monto.toStringAsFixed(2)}';
    if (r.comisionDevengada && r.comisionDevengadaAt != null) {
      text += ' · ${formatEsShortDateTime(r.comisionDevengadaAt)}';
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
