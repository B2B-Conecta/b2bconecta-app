class InAppNotificationModel {
  const InAppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.relatedId,
    this.productName,
    this.aliadoBusinessName,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedId;
  final String? productName;
  final String? aliadoBusinessName;

  factory InAppNotificationModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at']?.toString();
    return InAppNotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString().trim() ?? '',
      body: json['body']?.toString().trim() ?? '',
      type: json['type']?.toString().trim() ?? 'mensaje',
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(createdRaw ?? '') ?? DateTime.now(),
      relatedId: _nullableText(json['related_id']),
      productName: _nullableText(json['product_name']),
      aliadoBusinessName: _nullableText(json['aliado_business_name']),
    );
  }

  InAppNotificationModel copyWith({
    bool? isRead,
    String? productName,
    String? aliadoBusinessName,
  }) {
    return InAppNotificationModel(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      relatedId: relatedId,
      productName: productName ?? this.productName,
      aliadoBusinessName: aliadoBusinessName ?? this.aliadoBusinessName,
    );
  }

  static String? _nullableText(dynamic v) {
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }
}
