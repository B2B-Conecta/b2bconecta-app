/// Fila de `transportista_info`: expediente jurídico y base operativa (coords).
class TransportistaInfoModel {
  const TransportistaInfoModel({
    required this.id,
    this.rif,
    this.documentoConstitutivoStoragePath,
    this.rifDocumentoStoragePath,
    this.otrosDocumentosStoragePath,
    required this.baseOperativaLatitude,
    required this.baseOperativaLongitude,
    this.locationUpdatedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? rif;
  final String? documentoConstitutivoStoragePath;
  final String? rifDocumentoStoragePath;
  final String? otrosDocumentosStoragePath;
  final double baseOperativaLatitude;
  final double baseOperativaLongitude;
  final DateTime? locationUpdatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TransportistaInfoModel.fromJson(Map<String, dynamic> json) {
    double lat = 0;
    final latRaw = json['base_operativa_latitude'];
    if (latRaw is num) {
      lat = latRaw.toDouble();
    } else if (latRaw != null) {
      lat = double.tryParse(latRaw.toString()) ?? 0;
    }
    double lon = 0;
    final lonRaw = json['base_operativa_longitude'];
    if (lonRaw is num) {
      lon = lonRaw.toDouble();
    } else if (lonRaw != null) {
      lon = double.tryParse(lonRaw.toString()) ?? 0;
    }
    return TransportistaInfoModel(
      id: json['id']?.toString() ?? '',
      rif: _t(json['rif']),
      documentoConstitutivoStoragePath:
          _t(json['documento_constitutivo_storage_path']),
      rifDocumentoStoragePath: _t(json['rif_documento_storage_path']),
      otrosDocumentosStoragePath: _t(json['otros_documentos_storage_path']),
      baseOperativaLatitude: lat,
      baseOperativaLongitude: lon,
      locationUpdatedAt: _d(json['location_updated_at']),
      createdAt: _d(json['created_at']),
      updatedAt: _d(json['updated_at']),
    );
  }

  static String? _t(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static DateTime? _d(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

/// Candidato devuelto por el RPC `rpc_rank_transportistas_by_importer_proximity`.
class TransportistaProximityCandidate {
  const TransportistaProximityCandidate({
    required this.transportistaId,
    required this.businessName,
    required this.avgDistanceKm,
    required this.maxDistanceKm,
  });

  final String transportistaId;
  final String businessName;
  final double avgDistanceKm;
  final double maxDistanceKm;

  factory TransportistaProximityCandidate.fromJson(Map<String, dynamic> j) {
    double a = 0;
    final aRaw = j['avg_distance_km'];
    if (aRaw is num) {
      a = aRaw.toDouble();
    } else if (aRaw != null) {
      a = double.tryParse(aRaw.toString()) ?? 0;
    }
    double m = 0;
    final mRaw = j['max_distance_km'];
    if (mRaw is num) {
      m = mRaw.toDouble();
    } else if (mRaw != null) {
      m = double.tryParse(mRaw.toString()) ?? 0;
    }
    return TransportistaProximityCandidate(
      transportistaId: j['transportista_id']?.toString() ?? '',
      businessName: j['business_name']?.toString() ?? '',
      avgDistanceKm: a,
      maxDistanceKm: m,
    );
  }
}
