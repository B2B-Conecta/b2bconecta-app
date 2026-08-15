import 'support_ticket_category.dart';
import 'support_ticket_status.dart';

/// Reclamo de atención al cliente (`support_tickets`).
class SupportTicketModel {
  const SupportTicketModel({
    required this.id,
    required this.createdBy,
    required this.authorRole,
    required this.subject,
    required this.category,
    required this.status,
    this.relatedTransactionRequestId,
    this.closedBy,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
    this.creatorBusinessName,
    this.creatorEmail,
  });

  final String id;
  final String createdBy;
  final String authorRole;
  final String subject;
  final String category;
  final String status;
  final String? relatedTransactionRequestId;
  final String? closedBy;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? creatorBusinessName;
  final String? creatorEmail;

  bool get isOpen => SupportTicketStatus.isOpen(status);
  bool get isClosed => status.trim() == SupportTicketStatus.cerrado;

  String get statusLabel => SupportTicketStatus.labelEs(status);
  String get categoryLabel => SupportTicketCategory.labelEs(category);

  String get creatorDisplayName {
    final biz = creatorBusinessName?.trim();
    if (biz != null && biz.isNotEmpty) return biz;
    final email = creatorEmail?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Usuario';
  }

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? creator;
    final rawCreator = json['creator'];
    if (rawCreator is Map) {
      creator = Map<String, dynamic>.from(rawCreator);
    }

    return SupportTicketModel(
      id: json['id']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      authorRole: json['author_role']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      category: json['category']?.toString() ?? SupportTicketCategory.otro,
      status: json['status']?.toString() ?? SupportTicketStatus.abierto,
      relatedTransactionRequestId:
          json['related_transaction_request_id']?.toString(),
      closedBy: json['closed_by']?.toString(),
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      creatorBusinessName: creator?['business_name']?.toString(),
      creatorEmail: creator?['email']?.toString(),
    );
  }
}
