/// Valoración recibida por el aliado (`list_aliado_received_ratings`).
class AliadoReceivedRatingModel {
  const AliadoReceivedRatingModel({
    required this.id,
    required this.overallStars,
    required this.comment,
    required this.answers,
    required this.submittedAt,
    required this.importerLabel,
  });

  final String id;
  final int overallStars;
  final String comment;
  final Map<String, dynamic> answers;
  final DateTime? submittedAt;
  final String importerLabel;

  factory AliadoReceivedRatingModel.fromJson(Map<String, dynamic> json) {
    final ans = json['answers'];
    return AliadoReceivedRatingModel(
      id: json['id']?.toString() ?? '',
      overallStars: _asInt(json['overall_stars']),
      comment: json['comment']?.toString() ?? '',
      answers: ans is Map ? Map<String, dynamic>.from(ans) : const {},
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      importerLabel: json['importer_label']?.toString() ?? 'Importador',
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
