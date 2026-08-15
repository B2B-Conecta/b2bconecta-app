/// Resumen de aliado con KYC aprobado (`list_kyc_approved_aliados_for_importador`).
class KycApprovedAliadoModel {
  const KycApprovedAliadoModel({
    required this.id,
    this.businessName,
    this.rif,
    this.phone,
    this.estado,
    this.ciudad,
    this.direccion,
    this.fiscalMapsUrl,
    this.logoStoragePath,
    this.kycStatus,
    this.ratingAsPayerAvgRolling100,
    this.ratingAsPayerCountRolling100,
    this.approvedDocumentCount = 0,
  });

  final String id;
  final String? businessName;
  final String? rif;
  final String? phone;
  final String? estado;
  final String? ciudad;
  final String? direccion;
  final String? fiscalMapsUrl;
  final String? logoStoragePath;
  final String? kycStatus;
  final double? ratingAsPayerAvgRolling100;
  final int? ratingAsPayerCountRolling100;
  final int approvedDocumentCount;

  String get displayName {
    final n = businessName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Aliado';
  }

  String get locationLine {
    final e = estado?.trim();
    final c = ciudad?.trim();
    if (e != null && e.isNotEmpty && c != null && c.isNotEmpty) return '$e · $c';
    return e ?? c ?? '';
  }

  factory KycApprovedAliadoModel.fromJson(Map<String, dynamic> json) {
    return KycApprovedAliadoModel(
      id: json['id']?.toString() ?? '',
      businessName: json['business_name']?.toString(),
      rif: json['rif']?.toString(),
      phone: json['phone']?.toString(),
      estado: json['estado']?.toString(),
      ciudad: json['ciudad']?.toString(),
      direccion: json['direccion']?.toString(),
      fiscalMapsUrl: json['fiscal_maps_url']?.toString(),
      logoStoragePath: json['logo_storage_path']?.toString(),
      kycStatus: json['kyc_status']?.toString(),
      ratingAsPayerAvgRolling100:
          (json['rating_as_payer_avg_rolling100'] as num?)?.toDouble(),
      ratingAsPayerCountRolling100:
          (json['rating_as_payer_count_rolling100'] as num?)?.toInt(),
      approvedDocumentCount:
          (json['approved_document_count'] as num?)?.toInt() ?? 0,
    );
  }
}
