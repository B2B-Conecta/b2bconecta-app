import 'dart:convert';

/// Tramos E4 en `products.discount_rules`: unidades mínimas del mismo SKU.
class ProductVolumeTier {
  const ProductVolumeTier({
    required this.minUnits,
    required this.percentDiscount,
  });

  final int minUnits;
  final double percentDiscount;

  Map<String, dynamic> toJson() => {
        'min_units': minUnits,
        'percent_discount': percentDiscount,
      };

  static ProductVolumeTier? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final min = _asInt(m['min_units'] ?? m['min']);
    final pct = _asDouble(m['percent_discount'] ?? m['pct'] ?? m['percent']);
    if (min == null || min < 1 || pct == null || pct <= 0) return null;
    return ProductVolumeTier(minUnits: min, percentDiscount: pct);
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  static double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }
}

List<ProductVolumeTier> parseProductVolumeTiers(Map<String, dynamic>? rules) {
  if (rules == null || rules.isEmpty) return const [];
  final raw = rules['volume_tiers'];
  if (raw is! List) return const [];
  final out = <ProductVolumeTier>[];
  for (final e in raw) {
    final t = ProductVolumeTier.fromJson(e);
    if (t != null) out.add(t);
  }
  out.sort((a, b) => a.minUnits.compareTo(b.minUnits));
  return out;
}

Map<String, dynamic> productVolumeTiersToDiscountRules(
  List<ProductVolumeTier> tiers,
) {
  return buildProductDiscountRules(volumeTiers: tiers) ?? {};
}

/// % adicional en línea USD del catálogo (pago Zelle/divisas), sobre precio REF.
double? parseUsdPaymentDiscountPct(Map<String, dynamic>? rules) {
  if (rules == null || rules.isEmpty) return null;
  final raw = rules['usd_payment_discount_pct'];
  final pct = raw is num
      ? raw.toDouble()
      : double.tryParse(raw?.toString() ?? '');
  if (pct == null || pct <= 0 || pct >= 100) return null;
  return pct;
}

/// Arma `discount_rules` para guardar en `products` (importador).
Map<String, dynamic>? buildProductDiscountRules({
  List<ProductVolumeTier> volumeTiers = const [],
  double? usdPaymentDiscountPct,
}) {
  final sorted = [...volumeTiers]
    ..sort((a, b) => a.minUnits.compareTo(b.minUnits));
  final hasTiers = sorted.isNotEmpty;
  final pct = usdPaymentDiscountPct;
  final hasUsdPct = pct != null && pct > 0 && pct < 100;
  if (!hasTiers && !hasUsdPct) return null;

  final map = <String, dynamic>{};
  if (hasTiers) {
    map['volume_tiers'] = sorted.map((t) => t.toJson()).toList();
  }
  if (hasUsdPct) {
    map['usd_payment_discount_pct'] = pct;
  }
  return map;
}

/// Mejor tramo aplicable para [quantity] unidades.
ProductVolumeTier? activeProductVolumeTier(
  List<ProductVolumeTier> tiers,
  int quantity,
) {
  if (tiers.isEmpty || quantity < 1) return null;
  ProductVolumeTier? picked;
  for (final t in tiers) {
    if (quantity >= t.minUnits) {
      if (picked == null || t.minUnits >= picked.minUnits) {
        picked = t;
      }
    }
  }
  return picked;
}

/// Siguiente tramo no alcanzado (para badge preventa en ficha).
ProductVolumeTier? nextProductVolumeTier(
  List<ProductVolumeTier> tiers,
  int quantity,
) {
  for (final t in tiers) {
    if (quantity < t.minUnits) return t;
  }
  return null;
}

double? appliedVolumeDiscountPctFromSnapshot(Map<String, dynamic>? rules) {
  if (rules == null) return null;
  final v = rules['applied_volume_discount_pct'];
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '');
}

/// Parsea celda Excel `tramos_volumen_json`.
Map<String, dynamic>? parseVolumeTiersJsonCell(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return null;
  try {
    final decoded = jsonDecode(t);
    if (decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      return buildProductDiscountRules(
        volumeTiers: parseProductVolumeTiers(m),
        usdPaymentDiscountPct: parseUsdPaymentDiscountPct(m),
      );
    }
    if (decoded is List) {
      return buildProductDiscountRules(
        volumeTiers: decoded
            .map(ProductVolumeTier.fromJson)
            .whereType<ProductVolumeTier>()
            .toList(),
      );
    }
  } catch (_) {
    return null;
  }
  return null;
}
