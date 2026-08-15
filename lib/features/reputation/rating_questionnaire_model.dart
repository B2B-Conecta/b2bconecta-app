/// Cuestionario Bucket (config en `platform_settings`).
class RatingQuestionnaireModel {
  const RatingQuestionnaireModel({
    required this.version,
    required this.questions,
    this.scaleMin = 1,
    this.scaleMax = 5,
    this.labelScale = const [],
  });

  final String version;
  final List<RatingQuestionModel> questions;
  final int scaleMin;
  final int scaleMax;
  final List<RatingScaleLabelModel> labelScale;

  bool get isBucketV2 => version == 'bucket_v2';

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
    final labels = <RatingScaleLabelModel>[];
    final rawLabels = json['label_scale'];
    if (rawLabels is List) {
      for (final e in rawLabels) {
        if (e is! Map) continue;
        labels.add(
          RatingScaleLabelModel.fromJson(Map<String, dynamic>.from(e)),
        );
      }
    }
    return RatingQuestionnaireModel(
      version: json['version']?.toString() ?? 'bucket_v1',
      questions: qs,
      scaleMin: min,
      scaleMax: max,
      labelScale: labels,
    );
  }

  String labelForValue(int value) {
    for (final l in labelScale) {
      if (l.value == value) return l.labelEs;
    }
    return '';
  }

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}

class RatingScaleLabelModel {
  const RatingScaleLabelModel({required this.value, required this.labelEs});

  final int value;
  final String labelEs;

  factory RatingScaleLabelModel.fromJson(Map<String, dynamic> json) {
    return RatingScaleLabelModel(
      value: RatingQuestionnaireModel._asInt(json['value'], 1),
      labelEs: json['label_es']?.toString() ?? '',
    );
  }
}

class RatingQuestionModel {
  const RatingQuestionModel({
    required this.id,
    this.textEs,
    this.titleEs,
    this.subtitleEs,
    this.required = false,
  });

  final String id;
  final String? textEs;
  final String? titleEs;
  final String? subtitleEs;
  final bool required;

  String get displayTitle {
    final t = titleEs?.trim();
    if (t != null && t.isNotEmpty) return t;
    final legacy = textEs?.trim();
    if (legacy == null || legacy.isEmpty) return id;
    final colon = legacy.indexOf(':');
    if (colon > 0) return legacy.substring(0, colon).trim();
    return legacy;
  }

  String get displaySubtitle {
    final s = subtitleEs?.trim();
    if (s != null && s.isNotEmpty) return s;
    final legacy = textEs?.trim();
    if (legacy == null || legacy.isEmpty) return '';
    final colon = legacy.indexOf(':');
    if (colon >= 0 && colon < legacy.length - 1) {
      return legacy.substring(colon + 1).trim().replaceAll(RegExp(r'^\?+\s*'), '');
    }
    return legacy.replaceAll(RegExp(r'^\?+\s*'), '');
  }

  factory RatingQuestionModel.fromJson(Map<String, dynamic> json) {
    return RatingQuestionModel(
      id: json['id']?.toString() ?? '',
      textEs: json['text_es']?.toString(),
      titleEs: json['title_es']?.toString(),
      subtitleEs: json['subtitle_es']?.toString(),
      required: json['required'] == true,
    );
  }
}
