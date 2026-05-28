import '../models/transaction_request_model.dart';
import 'product_volume_tiers.dart';
import 'ves_amount_format.dart';

/// Resumen de descuento por volumen ya aplicado en el pedido (snapshot servidor).
class VolumeDiscountResult {
  const VolumeDiscountResult({
    required this.quantity,
    required this.percentApplied,
    required this.subtotalUsd,
    this.appliedMinUnits,
  });

  final int quantity;
  final double percentApplied;
  final double subtotalUsd;
  final int? appliedMinUnits;

  String get resumenEs {
    if (percentApplied <= 0) return '';
    final minPart = appliedMinUnits != null
        ? ' (desde $appliedMinUnits uds.)'
        : '';
    return 'Descuento por volumen$minPart: '
        '${percentApplied.toStringAsFixed(0)}% · '
        'Total línea USD ${formatRefAmount(subtotalUsd)}';
  }

  factory VolumeDiscountResult.fromLine(TransactionRequestModel r) {
    final rules = r.discountRules;
    final pct = appliedVolumeDiscountPctFromSnapshot(rules) ?? 0;
    final minRaw = rules?['applied_volume_min_units'];
    final minUnits = minRaw is int
        ? minRaw
        : (minRaw is num ? minRaw.toInt() : int.tryParse('$minRaw'));
    return VolumeDiscountResult(
      quantity: r.cantidad,
      percentApplied: pct,
      subtotalUsd: r.precioTotal,
      appliedMinUnits: minUnits,
    );
  }
}

/// Línea con descuento por volumen registrado en checkout.
VolumeDiscountResult? volumeDiscountFromOrderLine(TransactionRequestModel r) {
  final pct = appliedVolumeDiscountPctFromSnapshot(r.discountRules);
  if (pct == null || pct <= 0) return null;
  return VolumeDiscountResult.fromLine(r);
}

/// Varias líneas del mismo importador (muestra si alguna tiene volumen).
VolumeDiscountResult? computeVolumeDiscountForLines(
  List<TransactionRequestModel> lines,
) {
  for (final r in lines) {
    final d = volumeDiscountFromOrderLine(r);
    if (d != null) return d;
  }
  return null;
}
