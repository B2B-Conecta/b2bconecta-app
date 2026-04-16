/// Fila en `profile_documents` (metadatos de archivo en Storage).
class ProfileDocumentModel {
  const ProfileDocumentModel({
    required this.id,
    required this.profileId,
    required this.docType,
    required this.storagePath,
    this.fileName,
    this.createdAt,
    this.isCurrent = true,
    this.reviewStatus,
    this.reviewNote,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewerBusinessName,
  });

  final String id;
  final String profileId;
  final String docType;
  final String storagePath;
  final String? fileName;
  final DateTime? createdAt;

  /// Versión vigente del tipo de documento (solo una por `doc_type`).
  final bool isCurrent;

  /// Revisión individual MotoLink (`pendiente` … `aprobado`).
  final String? reviewStatus;

  /// Comentario del broker al aprobar/rechazar (visible para el aliado si aplica).
  final String? reviewNote;

  final DateTime? reviewedAt;

  /// `profiles.id` del administrador que revisó por última vez.
  final String? reviewedBy;

  /// Nombre comercial del revisor (join opcional `profiles`).
  final String? reviewerBusinessName;

  factory ProfileDocumentModel.fromJson(Map<String, dynamic> json) {
    String? reviewerName;
    final rev = json['reviewer'];
    if (rev is Map) {
      reviewerName = _text(Map<String, dynamic>.from(rev)['business_name']);
    } else if (rev is List && rev.isNotEmpty && rev.first is Map) {
      reviewerName =
          _text(Map<String, dynamic>.from(rev.first as Map)['business_name']);
    }

    return ProfileDocumentModel(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      docType: json['doc_type']?.toString() ?? '',
      storagePath: json['storage_path']?.toString() ?? '',
      fileName: json['file_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      isCurrent: json['is_current'] is bool
          ? json['is_current'] as bool
          : (json['is_current']?.toString().toLowerCase() != 'false'),
      reviewStatus: _text(json['review_status']),
      reviewNote: _text(json['review_note']),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'].toString())
          : null,
      reviewedBy: _text(json['reviewed_by']),
      reviewerBusinessName: reviewerName,
    );
  }

  static String? _text(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
