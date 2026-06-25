/// Conductor asociado a un transportista del importador.
class ImporterCarrierDriverModel {
  const ImporterCarrierDriverModel({
    required this.id,
    required this.carrierId,
    required this.importadorId,
    required this.driverName,
    this.contactPhone,
    this.licenseId,
    this.notes,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String carrierId;
  final String importadorId;
  final String driverName;
  final String? contactPhone;
  final String? licenseId;
  final String? notes;
  final bool isActive;
  final int sortOrder;

  factory ImporterCarrierDriverModel.fromJson(Map<String, dynamic> json) {
    return ImporterCarrierDriverModel(
      id: json['id']?.toString() ?? '',
      carrierId: json['carrier_id']?.toString() ?? '',
      importadorId: json['importador_id']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? '',
      contactPhone: json['contact_phone']?.toString(),
      licenseId: json['license_id']?.toString(),
      notes: json['notes']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
