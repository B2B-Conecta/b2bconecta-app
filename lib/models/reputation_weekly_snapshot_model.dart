import 'rating_dimension_stat_model.dart';

/// Fila de `reputation_weekly_snapshots` (cierre semanal E2).
class ReputationWeeklySnapshotModel {
  const ReputationWeeklySnapshotModel({
    required this.weekStart,
    this.avgOverall,
    required this.ratingCount,
    this.dimensions = const {},
  });

  final DateTime weekStart;
  final double? avgOverall;
  final int ratingCount;
  final Map<String, RatingDimensionStatModel> dimensions;

  factory ReputationWeeklySnapshotModel.fromJson(Map<String, dynamic> json) {
    final ws = json['week_start']?.toString();
    return ReputationWeeklySnapshotModel(
      weekStart: ws != null ? DateTime.parse(ws) : DateTime.now(),
      avgOverall: _asDouble(json['avg_overall']),
      ratingCount: _asInt(json['rating_count']) ?? 0,
      dimensions: RatingDimensionStatModel.mapFromProfileJson(json['dimensions']),
    );
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
