class ImporterPickupLocationModel {
  const ImporterPickupLocationModel({
    required this.id,
    required this.importadorId,
    required this.label,
    required this.direccion,
    this.estado,
    this.ciudad,
    this.latitude,
    this.longitude,
    this.mapsUrl,
    this.contactName,
    this.contactPhone,
    this.isActive = true,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  final String id;
  final String importadorId;
  final String label;
  final String? estado;
  final String? ciudad;
  final String direccion;
  final double? latitude;
  final double? longitude;
  final String? mapsUrl;
  final String? contactName;
  final String? contactPhone;
  final bool isActive;
  final bool isDefault;
  final int sortOrder;

  String get ubicacionMultilinea {
    final parts = <String>[];
    final e = estado?.trim();
    final c = ciudad?.trim();
    final d = direccion.trim();
    if (e != null && e.isNotEmpty) parts.add(e);
    if (c != null && c.isNotEmpty) parts.add(c);
    if (d.isNotEmpty) parts.add(d);
    return parts.join('\n');
  }

  factory ImporterPickupLocationModel.fromJson(Map<String, dynamic> json) {
    double? dbl(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ImporterPickupLocationModel(
      id: json['id']?.toString() ?? '',
      importadorId: json['importador_id']?.toString() ?? '',
      label: json['label']?.toString().trim() ?? '',
      estado: json['estado']?.toString().trim(),
      ciudad: json['ciudad']?.toString().trim(),
      direccion: json['direccion']?.toString().trim() ?? '',
      latitude: dbl(json['latitude']),
      longitude: dbl(json['longitude']),
      mapsUrl: json['maps_url']?.toString().trim(),
      contactName: json['contact_name']?.toString().trim(),
      contactPhone: json['contact_phone']?.toString().trim(),
      isActive: json['is_active'] != false,
      isDefault: json['is_default'] == true,
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }
}
