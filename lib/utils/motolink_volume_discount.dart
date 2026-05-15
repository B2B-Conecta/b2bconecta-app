import '../models/transaction_request_model.dart';
import 'ves_amount_format.dart';

/// Tramos opcionales en `discount_rules` (producto / línea de pedido), p. ej.:
/// `{ "volume_tiers": [ { "min_subtotal_ref": 1000, "percent_discount": 5 } ] }`
class VolumeDiscountTier {
  const VolumeDiscountTier({
    required this.minSubtotalRef,
    required this.percentDiscount,
  });

  final double minSubtotalRef;
  final double percentDiscount;
}

class VolumeDiscountResult {
  const VolumeDiscountResult({
    required this.subtotalRef,
    required this.percentApplied,
    required this.amountOff,
    required this.totalAfterDiscount,
  });

  final double subtotalRef;
  final double percentApplied;
  final double amountOff;
  final double totalAfterDiscount;

  String get resumenEs {
    if (percentApplied <= 0) return '';
    return 'Subtotal ${formatRefAmount(subtotalRef)} REF · '
        '${percentApplied.toStringAsFixed(0)} % descuento por volumen · '
        'Total ${formatRefAmount(totalAfterDiscount)} REF';
  }
}

List<VolumeDiscountTier> _tiersFromRules(Map<String, dynamic>? rules) {
  if (rules == null || rules.isEmpty) return const [];
  final raw = rules['volume_tiers'];
  if (raw is! List) return const [];
  final out = <VolumeDiscountTier>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final minV = m['min_subtotal_ref'] ?? m['min'];
    final pctV = m['percent_discount'] ?? m['pct'] ?? m['percent'];
    final min = minV is num
        ? minV.toDouble()
        : double.tryParse(minV?.toString() ?? '') ?? 0;
    final pct = pctV is num
        ? pctV.toDouble()
        : double.tryParse(pctV?.toString() ?? '') ?? 0;
    if (min > 0 && pct > 0) {
      out.add(VolumeDiscountTier(minSubtotalRef: min, percentDiscount: pct));
    }
  }
  out.sort((a, b) => b.minSubtotalRef.compareTo(a.minSubtotalRef));
  return out;
}

/// Evalúa descuento por volumen sobre el subtotal de las líneas (mismo importador).
VolumeDiscountResult? computeVolumeDiscountForLines(
  List<TransactionRequestModel> lines,
) {
  if (lines.isEmpty) return null;
  final subtotal = lines.fold<double>(0, (s, r) => s + r.precioTotal);
  Map<String, dynamic>? rules;
  for (final r in lines) {
    final m = r.discountRules;
    if (m != null && m.isNotEmpty) {
      rules = m;
      break;
    }
  }
  final tiers = _tiersFromRules(rules);
  if (tiers.isEmpty) return null;
  VolumeDiscountTier? picked;
  for (final t in tiers) {
    if (subtotal + 1e-9 >= t.minSubtotalRef) {
      picked = t;
      break;
    }
  }
  if (picked == null) return null;
  final off = subtotal * (picked.percentDiscount / 100.0);
  final after = (subtotal - off).clamp(0.0, 1e15);
  return VolumeDiscountResult(
    subtotalRef: subtotal,
    percentApplied: picked.percentDiscount,
    amountOff: off,
    totalAfterDiscount: after,
  );
}
