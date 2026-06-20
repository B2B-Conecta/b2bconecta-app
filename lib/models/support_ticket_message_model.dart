/// Mensaje en un reclamo de soporte (`support_ticket_messages`).
class SupportTicketMessageModel {
  const SupportTicketMessageModel({
    required this.id,
    required this.ticketId,
    required this.authorId,
    required this.authorRole,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String ticketId;
  final String authorId;
  final String authorRole;
  final String body;
  final DateTime? createdAt;

  bool get isFromAdmin => authorRole.trim() == 'administrador';
  bool get isFromImportador => authorRole.trim() == 'importador';
  bool get isFromAliado => authorRole.trim() == 'aliado';

  factory SupportTicketMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessageModel(
      id: json['id']?.toString() ?? '',
      ticketId: json['ticket_id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorRole: json['author_role']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
