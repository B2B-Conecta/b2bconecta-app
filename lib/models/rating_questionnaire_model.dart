/// Cuestionario Bucket List (config en `platform_settings`).
class RatingQuestionnaireModel {
  const RatingQuestionnaireModel({
    required this.version,
    required this.questions,
    this.scaleMin = 1,
    this.scaleMax = 5,
  });

  final String version;
  final List<RatingQuestionModel> questions;
  final int scaleMin;
  final int scaleMax;

  factory RatingQuestionnaireModel.fromJson(Map<String, dynamic> json) {
    final scale = json['scale'];
    var min = 1;
    var max = 5;
    if (scale is Map) {
      final sm = Map<String, dynamic>.from(scale);
      min = _asInt(sm['min'], 1);
      max = _asInt(sm['max'], 5);
    }
    final raw = json['questions'];
    final qs = <RatingQuestionModel>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        qs.add(RatingQuestionModel.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return RatingQuestionnaireModel(
      version: json['version']?.toString() ?? 'bucket_v1',
      questions: qs,
      scaleMin: min,
      scaleMax: max,
    );
  }

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}

class RatingQuestionModel {
  const RatingQuestionModel({
    required this.id,
    required this.textEs,
  });

  final String id;
  final String textEs;

  factory RatingQuestionModel.fromJson(Map<String, dynamic> json) {
    return RatingQuestionModel(
      id: json['id']?.toString() ?? '',
      textEs: json['text_es']?.toString() ?? '',
    );
  }
}
