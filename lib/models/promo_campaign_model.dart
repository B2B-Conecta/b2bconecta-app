/// Campaña promocional E1.2 (banner / popup en catálogo aliado).
class PromoCampaignModel {
  const PromoCampaignModel({
    required this.id,
    required this.internalTitle,
    this.displayTitle,
    required this.campaignType,
    required this.imageStoragePath,
    required this.imagePublicUrl,
    this.importadorId,
    required this.actionType,
    required this.startsAt,
    required this.endsAt,
    required this.priority,
    required this.isActive,
    this.createdAt,
  });

  static const typeBanner = 'banner';
  static const typePopup = 'popup';
  static const actionNone = 'none';
  static const actionFilterImporter = 'filter_importer';

  final String id;
  final String internalTitle;
  final String? displayTitle;
  final String campaignType;
  final String imageStoragePath;
  final String imagePublicUrl;
  final String? importadorId;
  final String actionType;
  final DateTime startsAt;
  final DateTime endsAt;
  final int priority;
  final bool isActive;
  final DateTime? createdAt;

  bool get isBanner => campaignType == typeBanner;
  bool get isPopup => campaignType == typePopup;
  bool get filtersImporter =>
      actionType == actionFilterImporter &&
      importadorId != null &&
      importadorId!.trim().isNotEmpty;

  String get promoLabel {
    final t = displayTitle?.trim();
    if (t != null && t.isNotEmpty) return t;
    return 'Promoción';
  }

  factory PromoCampaignModel.fromJson(Map<String, dynamic> json) {
    return PromoCampaignModel(
      id: json['id']?.toString() ?? '',
      internalTitle: json['internal_title']?.toString() ?? '',
      displayTitle: json['display_title']?.toString(),
      campaignType: json['campaign_type']?.toString() ?? typeBanner,
      imageStoragePath: json['image_storage_path']?.toString() ?? '',
      imagePublicUrl: json['image_public_url']?.toString() ?? '',
      importadorId: json['importador_id']?.toString(),
      actionType: json['action_type']?.toString() ?? actionNone,
      startsAt: DateTime.parse(json['starts_at'].toString()).toLocal(),
      endsAt: DateTime.parse(json['ends_at'].toString()).toLocal(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toInsertJson({required String createdBy}) {
    return {
      'internal_title': internalTitle.trim(),
      'display_title': displayTitle?.trim().isEmpty ?? true
          ? null
          : displayTitle!.trim(),
      'campaign_type': campaignType,
      'image_storage_path': imageStoragePath,
      'image_public_url': imagePublicUrl,
      'importador_id': importadorId,
      'action_type': actionType,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'priority': priority,
      'is_active': isActive,
      'created_by': createdBy,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'internal_title': internalTitle.trim(),
      'display_title': displayTitle?.trim().isEmpty ?? true
          ? null
          : displayTitle!.trim(),
      'campaign_type': campaignType,
      'image_storage_path': imageStoragePath,
      'image_public_url': imagePublicUrl,
      'importador_id': importadorId,
      'action_type': actionType,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'priority': priority,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Respuesta compacta del RPC aliado.
  factory PromoCampaignModel.fromAliadoRpcJson(Map<String, dynamic> json) {
    return PromoCampaignModel(
      id: json['id']?.toString() ?? '',
      internalTitle: '',
      displayTitle: json['display_title']?.toString(),
      campaignType: json['campaign_type']?.toString() ?? typeBanner,
      imageStoragePath: '',
      imagePublicUrl: json['image_public_url']?.toString() ?? '',
      importadorId: json['importador_id']?.toString(),
      actionType: json['action_type']?.toString() ?? actionNone,
      startsAt: DateTime.now(),
      endsAt: DateTime.now(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: true,
    );
  }

  /// Respuesta del RPC importador (incluye fechas y título interno).
  factory PromoCampaignModel.fromImportadorRpcJson(Map<String, dynamic> json) {
    return PromoCampaignModel(
      id: json['id']?.toString() ?? '',
      internalTitle: json['internal_title']?.toString() ?? '',
      displayTitle: json['display_title']?.toString(),
      campaignType: json['campaign_type']?.toString() ?? typeBanner,
      imageStoragePath: '',
      imagePublicUrl: json['image_public_url']?.toString() ?? '',
      importadorId: null,
      actionType: actionNone,
      startsAt: DateTime.parse(json['starts_at'].toString()).toLocal(),
      endsAt: DateTime.parse(json['ends_at'].toString()).toLocal(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: true,
    );
  }
}
