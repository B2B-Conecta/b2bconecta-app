/// Fila de `list_admin_order_ratings` (expediente admin).
class AdminOrderRatingRowModel {
  const AdminOrderRatingRowModel({
    required this.id,
    required this.overallStars,
    required this.comment,
    required this.answers,
    this.questionnaireVersion,
    required this.submittedAt,
    required this.raterRole,
    required this.rateeRole,
    required this.importadorId,
    required this.importadorName,
    required this.aliadoId,
    required this.aliadoName,
    this.checkoutGroupId,
  });

  final String id;
  final int overallStars;
  final String comment;
  final Map<String, dynamic> answers;
  final String? questionnaireVersion;
  final DateTime? submittedAt;
  final String raterRole;
  final String rateeRole;
  final String importadorId;
  final String importadorName;
  final String aliadoId;
  final String aliadoName;
  final String? checkoutGroupId;

  factory AdminOrderRatingRowModel.fromJson(Map<String, dynamic> json) {
    final ans = json['answers'];
    return AdminOrderRatingRowModel(
      id: json['id']?.toString() ?? '',
      overallStars: _asInt(json['overall_stars']),
      comment: json['comment']?.toString() ?? '',
      answers: ans is Map ? Map<String, dynamic>.from(ans) : const {},
      questionnaireVersion: json['questionnaire_version']?.toString(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      raterRole: json['rater_role']?.toString() ?? '',
      rateeRole: json['ratee_role']?.toString() ?? '',
      importadorId: json['importador_id']?.toString() ?? '',
      importadorName: json['importador_name']?.toString() ?? '',
      aliadoId: json['aliado_id']?.toString() ?? '',
      aliadoName: json['aliado_name']?.toString() ?? '',
      checkoutGroupId: json['checkout_group_id']?.toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String get raterLabelEs =>
      raterRole == 'aliado' ? 'Aliado → importador' : 'Importador → aliado';

  bool get isBucketV2 => questionnaireVersion == 'bucket_v2';
}
