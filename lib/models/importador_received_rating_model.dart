class ImportadorReceivedRatingModel {
  const ImportadorReceivedRatingModel({
    required this.id,
    required this.overallStars,
    required this.comment,
    required this.answers,
    required this.submittedAt,
    required this.aliadoLabel,
  });

  final String id;
  final int overallStars;
  final String comment;
  final Map<String, dynamic> answers;
  final DateTime? submittedAt;
  final String aliadoLabel;

  factory ImportadorReceivedRatingModel.fromJson(Map<String, dynamic> json) {
    final ans = json['answers'];
    return ImportadorReceivedRatingModel(
      id: json['id']?.toString() ?? '',
      overallStars: _asInt(json['overall_stars']),
      comment: json['comment']?.toString() ?? '',
      answers: ans is Map ? Map<String, dynamic>.from(ans) : const {},
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      aliadoLabel: json['aliado_label']?.toString() ?? 'Aliado',
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  int? answerFor(String questionId) {
    final v = answers[questionId];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}
