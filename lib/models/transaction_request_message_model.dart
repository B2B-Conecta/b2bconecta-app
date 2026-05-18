/// Mensaje aliado ↔ MotoLink en un pedido (`transaction_request_messages`).
class TransactionRequestMessageModel {
  const TransactionRequestMessageModel({
    required this.id,
    required this.transactionRequestId,
    required this.authorId,
    required this.authorRole,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String transactionRequestId;
  final String authorId;
  final String authorRole;
  final String body;
  final DateTime? createdAt;

  bool get isFromAdmin => authorRole.trim() == 'administrador';

  bool get isFromImportador => authorRole.trim() == 'importador';

  bool get isFromAliado => authorRole.trim() == 'aliado';

  factory TransactionRequestMessageModel.fromJson(Map<String, dynamic> json) {
    return TransactionRequestMessageModel(
      id: json['id']?.toString() ?? '',
      transactionRequestId: json['transaction_request_id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorRole: json['author_role']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
