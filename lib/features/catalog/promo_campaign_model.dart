/// Campaña promocional E1.2 (banner / popup en catálogo y vallas de terceros).
class PromoCampaignModel {
  const PromoCampaignModel({
    required this.id,
    required this.internalTitle,
    this.displayTitle,
    required this.campaignType,
    required this.imageStoragePath,
    required this.imagePublicUrl,
    this.importadorId,
    this.productId,
    this.productIds = const [],
    this.discountPercent,
    required this.actionType,
    required this.startsAt,
    required this.endsAt,
    required this.priority,
    required this.isActive,
    this.createdAt,
    this.sponsorType = sponsorImportador,
    this.audience = audienceAliado,
    this.advertiserName,
    this.externalUrl,
  });

  static const typeBanner = 'banner';
  static const typePopup = 'popup';
  static const actionNone = 'none';
  static const actionFilterImporter = 'filter_importer';
  static const actionExternalUrl = 'external_url';
  static const actionOpenStore = 'open_store';
  static const actionOpenProduct = 'open_product';

  static const sponsorImportador = 'importador';
  static const sponsorTercero = 'tercero';

  static const audienceAliado = 'aliado';
  static const audienceImportador = 'importador';
  static const audienceAmbos = 'ambos';

  final String id;
  final String internalTitle;
  final String? displayTitle;
  final String campaignType;
  final String imageStoragePath;
  final String imagePublicUrl;
  final String? importadorId;
  /// Compat: primer producto de [productIds].
  final String? productId;
  final List<String> productIds;
  /// % descuento de valla sobre lista (null = sin precio promo).
  final double? discountPercent;
  final String actionType;
  final DateTime startsAt;
  final DateTime endsAt;
  final int priority;
  final bool isActive;
  final DateTime? createdAt;
  final String sponsorType;
  final String audience;
  final String? advertiserName;
  final String? externalUrl;

  bool get isBanner => campaignType == typeBanner;
  bool get isPopup => campaignType == typePopup;
  bool get isThirdParty => sponsorType == sponsorTercero;
  bool get isImporterSponsored => sponsorType == sponsorImportador;

  List<String> get resolvedProductIds {
    final fromList = productIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (fromList.isNotEmpty) return fromList;
    final single = productId?.trim();
    if (single != null && single.isNotEmpty) return [single];
    return const [];
  }

  bool get filtersImporter =>
      actionType == actionFilterImporter &&
      importadorId != null &&
      importadorId!.trim().isNotEmpty;

  bool get opensExternalUrl {
    final url = externalUrl?.trim();
    return actionType == actionExternalUrl &&
        url != null &&
        url.isNotEmpty;
  }

  bool get opensStore =>
      actionType == actionOpenStore &&
      importadorId != null &&
      importadorId!.trim().isNotEmpty;

  bool get opensProduct =>
      actionType == actionOpenProduct &&
      importadorId != null &&
      importadorId!.trim().isNotEmpty &&
      resolvedProductIds.isNotEmpty;

  bool get hasProductDiscount {
    final pct = discountPercent;
    return pct != null && pct > 0 && pct < 100 && resolvedProductIds.isNotEmpty;
  }

  bool get isTappable =>
      filtersImporter || opensExternalUrl || opensStore || opensProduct;

  static double? parseDiscountPercent(dynamic raw) {
    if (raw == null) return null;
    final n = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (n == null || n <= 0 || n >= 100) return null;
    return n;
  }

  String get destinationCtaLabel {
    if (opensProduct) {
      return resolvedProductIds.length > 1 ? 'Ver productos' : 'Ver producto';
    }
    if (opensStore) return 'Ver vitrina';
    if (filtersImporter) return 'Ver proveedor';
    return '';
  }

  String get badgeLabel => isThirdParty ? 'Publicidad' : 'Promoción';

  String get promoLabel {
    if (isThirdParty) {
      final adv = advertiserName?.trim();
      if (adv != null && adv.isNotEmpty) return adv;
    }
    final t = displayTitle?.trim();
    if (t != null && t.isNotEmpty) return t;
    return isThirdParty ? 'Anuncio' : 'Promoción';
  }

  static String audienceLabelEs(String? value) {
    switch (value?.trim()) {
      case audienceAliado:
        return 'Solo tiendas minoristas';
      case audienceImportador:
        return 'Solo importadores';
      case audienceAmbos:
        return 'Tiendas tiendas minoristas e importadores';
      default:
        return value ?? '—';
    }
  }

  static List<String> _parseProductIds(dynamic raw, {String? fallbackId}) {
    final out = <String>[];
    if (raw is List) {
      for (final e in raw) {
        final id = e?.toString().trim() ?? '';
        if (id.isNotEmpty && !out.contains(id)) out.add(id);
      }
    }
    if (out.isEmpty) {
      final single = fallbackId?.trim();
      if (single != null && single.isNotEmpty) out.add(single);
    }
    return out;
  }

  factory PromoCampaignModel.fromJson(Map<String, dynamic> json) {
    final single = json['product_id']?.toString();
    final ids = _parseProductIds(json['product_ids'], fallbackId: single);
    return PromoCampaignModel(
      id: json['id']?.toString() ?? '',
      internalTitle: json['internal_title']?.toString() ?? '',
      displayTitle: json['display_title']?.toString(),
      campaignType: json['campaign_type']?.toString() ?? typeBanner,
      imageStoragePath: json['image_storage_path']?.toString() ?? '',
      imagePublicUrl: json['image_public_url']?.toString() ?? '',
      importadorId: json['importador_id']?.toString(),
      productId: ids.isEmpty ? single : ids.first,
      productIds: ids,
      discountPercent: parseDiscountPercent(json['discount_percent']),
      actionType: json['action_type']?.toString() ?? actionNone,
      startsAt: DateTime.parse(json['starts_at'].toString()).toLocal(),
      endsAt: DateTime.parse(json['ends_at'].toString()).toLocal(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
      sponsorType: json['sponsor_type']?.toString() ?? sponsorImportador,
      audience: json['audience']?.toString() ?? audienceAliado,
      advertiserName: json['advertiser_name']?.toString(),
      externalUrl: json['external_url']?.toString(),
    );
  }

  Map<String, dynamic> toInsertJson({required String createdBy}) {
    final ids = resolvedProductIds;
    return {
      'internal_title': internalTitle.trim(),
      'display_title': displayTitle?.trim().isEmpty ?? true
          ? null
          : displayTitle!.trim(),
      'campaign_type': campaignType,
      'image_storage_path': imageStoragePath,
      'image_public_url': imagePublicUrl,
      'importador_id': importadorId,
      'product_id': ids.isEmpty ? null : ids.first,
      'product_ids': ids,
      'discount_percent': hasProductDiscount ? discountPercent : null,
      'action_type': actionType,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'priority': priority,
      'is_active': isActive,
      'sponsor_type': sponsorType,
      'audience': audience,
      'advertiser_name': advertiserName?.trim().isEmpty ?? true
          ? null
          : advertiserName!.trim(),
      'external_url': externalUrl?.trim().isEmpty ?? true
          ? null
          : externalUrl!.trim(),
      'created_by': createdBy,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final ids = resolvedProductIds;
    return {
      'internal_title': internalTitle.trim(),
      'display_title': displayTitle?.trim().isEmpty ?? true
          ? null
          : displayTitle!.trim(),
      'campaign_type': campaignType,
      'image_storage_path': imageStoragePath,
      'image_public_url': imagePublicUrl,
      'importador_id': importadorId,
      'product_id': ids.isEmpty ? null : ids.first,
      'product_ids': ids,
      'discount_percent': hasProductDiscount ? discountPercent : null,
      'action_type': actionType,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'priority': priority,
      'is_active': isActive,
      'sponsor_type': sponsorType,
      'audience': audience,
      'advertiser_name': advertiserName?.trim().isEmpty ?? true
          ? null
          : advertiserName!.trim(),
      'external_url': externalUrl?.trim().isEmpty ?? true
          ? null
          : externalUrl!.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Respuesta compacta del RPC aliado / vallas importador.
  factory PromoCampaignModel.fromAliadoRpcJson(Map<String, dynamic> json) {
    final single = json['product_id']?.toString();
    final ids = _parseProductIds(json['product_ids'], fallbackId: single);
    return PromoCampaignModel(
      id: json['id']?.toString() ?? '',
      internalTitle: '',
      displayTitle: json['display_title']?.toString(),
      campaignType: json['campaign_type']?.toString() ?? typeBanner,
      imageStoragePath: '',
      imagePublicUrl: json['image_public_url']?.toString() ?? '',
      importadorId: json['importador_id']?.toString(),
      productId: ids.isEmpty ? single : ids.first,
      productIds: ids,
      discountPercent: parseDiscountPercent(json['discount_percent']),
      actionType: json['action_type']?.toString() ?? actionNone,
      startsAt: DateTime.now(),
      endsAt: DateTime.now(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: true,
      sponsorType: json['sponsor_type']?.toString() ?? sponsorImportador,
      audience: json['audience']?.toString() ?? audienceAliado,
      advertiserName: json['advertiser_name']?.toString(),
      externalUrl: json['external_url']?.toString(),
    );
  }

  /// Respuesta del RPC importador (campañas propias en catálogo aliado).
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
      sponsorType: sponsorImportador,
      audience: audienceAliado,
    );
  }
}
