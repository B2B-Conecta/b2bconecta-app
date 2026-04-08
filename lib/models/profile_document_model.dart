/// Fila en `profile_documents` (metadatos de archivo en Storage).
class ProfileDocumentModel {
  const ProfileDocumentModel({
    required this.id,
    required this.profileId,
    required this.docType,
    required this.storagePath,
    this.fileName,
    this.createdAt,
  });

  final String id;
  final String profileId;
  final String docType;
  final String storagePath;
  final String? fileName;
  final DateTime? createdAt;

  factory ProfileDocumentModel.fromJson(Map<String, dynamic> json) {
    return ProfileDocumentModel(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      docType: json['doc_type']?.toString() ?? '',
      storagePath: json['storage_path']?.toString() ?? '',
      fileName: json['file_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
