/// Promedio y muestra de una dimensión (desde `profiles.rating_dimensions_received_rolling100`).
class RatingDimensionStatModel {
  const RatingDimensionStatModel({
    required this.average,
    required this.count,
  });

  final double average;
  final int count;

  static RatingDimensionStatModel? fromJsonEntry(dynamic raw) {
    if (raw is! Map) return null;
    final avgRaw = raw['avg'];
    final cntRaw = raw['count'];
    final avg = avgRaw is num
        ? avgRaw.toDouble()
        : double.tryParse(avgRaw?.toString() ?? '');
    final count = cntRaw is int
        ? cntRaw
        : (cntRaw is num ? cntRaw.toInt() : int.tryParse(cntRaw?.toString() ?? ''));
    if (avg == null || count == null || count <= 0) return null;
    return RatingDimensionStatModel(average: avg, count: count);
  }

  static Map<String, RatingDimensionStatModel> mapFromProfileJson(
    dynamic json,
  ) {
    if (json is! Map) return const {};
    final out = <String, RatingDimensionStatModel>{};
    for (final e in json.entries) {
      final stat = fromJsonEntry(e.value);
      if (stat != null) out[e.key.toString()] = stat;
    }
    return out;
  }
}
