import 'cash_phase_policy.dart';
import 'rating_dimension_stat_model.dart';

/// Perfil B2B en Supabase (`profiles`), alineado a `auth.users.id`.
class ProfileModel {
  const ProfileModel({
    required this.id,
    this.businessName,
    this.rif,
    this.role,
    this.phone,
    this.createdAt,
    this.creditScore,
    this.creditLimit,
    this.kycStatus,
    this.primerosPedidosContadoEntregados,
    this.creditoConsumidoAcumulado,
    this.creditoPreactivadoPorAdmin = false,
    this.pedidosSuspendidosMorosidad = false,
    this.estado,
    this.ciudad,
    this.direccion,
    this.logoStoragePath,
    this.fiscalMapsUrl,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.ratingAvgReceived,
    this.ratingCountReceived,
    this.ratingAvgReceivedRolling100,
    this.ratingCountReceivedRolling100,
    this.ratingDimensionsReceivedRolling100 = const {},
    this.ratingAsPayerAvg,
    this.ratingAsPayerCount,
  });

  final String id;
  final String? businessName;
  final String? rif;

  /// `importador`, `aliado` o `administrador` (broker MotoLink).
  final String? role;
  final String? phone;
  final DateTime? createdAt;

  /// Legado en base de datos; ya no define cupo en la app.
  final int? creditScore;
  final double? creditLimit;

  /// Verificación documental MotoLink (`pendiente` … `aprobado`); solo aliados.
  final String? kycStatus;

  /// Entregas completadas contadas hacia la fase “primeros 3 pedidos contado” (0–3).
  final int? primerosPedidosContadoEntregados;

  /// Legado en base de datos; ya no se usa para cupo en plataforma.
  final double? creditoConsumidoAcumulado;

  /// Legado en base de datos (`credito_preactivado_por_admin`); ya no usado en UI.
  final bool creditoPreactivadoPorAdmin;

  /// MotoLink suspendió nuevos pedidos por morosidad (entregas con pago sin aprobar).
  final bool pedidosSuspendidosMorosidad;

  /// Estado / ciudad (Venezuela u otro) para catálogo y pedidos.
  final String? estado;
  final String? ciudad;

  /// Domicilio fiscal / dirección de la empresa (`profiles.direccion`).
  final String? direccion;

  /// Logo del negocio en Storage (`profile-logos/{uid}/...`); opcional.
  final String? logoStoragePath;

  /// Enlace público (p. ej. Google Maps) a la ubicación fiscal; opcional.
  final String? fiscalMapsUrl;

  /// Coordenadas para catálogo por proximidad (GPS aliado o geocodificación de domicilio fiscal).
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;

  /// Promedio 1–5 como proveedor (valoraciones de aliados).
  final double? ratingAvgReceived;
  final int? ratingCountReceived;

  /// Promedio 1–5 sobre las últimas 100 valoraciones (E2.1, catálogo).
  final double? ratingAvgReceivedRolling100;
  final int? ratingCountReceivedRolling100;

  /// Promedios por dimensión bucket_v2 (últ. 100), clave = question id.
  final Map<String, RatingDimensionStatModel> ratingDimensionsReceivedRolling100;

  /// Promedio 1–5 como pagador (valoraciones de importadores; v2 crédito).
  final double? ratingAsPayerAvg;
  final int? ratingAsPayerCount;

  /// Estado, ciudad y dirección fiscal (domicilio) — requisito para pedidos y perfil completo.
  bool get hasRegisteredLocation {
    final e = estado?.trim();
    final c = ciudad?.trim();
    final d = direccion?.trim();
    return e != null &&
        e.isNotEmpty &&
        c != null &&
        c.isNotEmpty &&
        d != null &&
        d.isNotEmpty;
  }

  /// Enlace «Compartir» de Google Maps u otra URL https al domicilio fiscal (rutas automáticas).
  bool get hasFiscalMapsShareLink {
    final u = fiscalMapsUrl?.trim();
    if (u == null || u.isEmpty) return false;
    final uri = Uri.tryParse(u);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// `true` mientras no haya completado las primeras [CashPhasePolicy.entregasRequeridas] entregas
  /// en modalidad contado (onboarding). Tras esa fase negocia pago y cuotas con cada importador.
  bool get esAliadoEnFaseContado {
    if (role?.trim().toLowerCase() != 'aliado') return false;
    return (primerosPedidosContadoEntregados ?? 0) < CashPhasePolicy.entregasRequeridas;
  }

  /// Datos mínimos para considerar el perfil listo (catálogo / RLS).
  bool get isComplete {
    final r = role?.trim().toLowerCase();
    final hasRole = r == 'importador' ||
        r == 'aliado' ||
        r == 'administrador';
    final base = businessName != null &&
        businessName!.trim().isNotEmpty &&
        rif != null &&
        rif!.trim().isNotEmpty &&
        hasRole;
    if (!base) return false;
    if (r == 'administrador') return true;
    if (!hasRegisteredLocation) return false;
    if (r == 'importador' || r == 'aliado') {
      return hasFiscalMapsShareLink;
    }
    return true;
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    double? cl;
    final clRaw = json['credit_limit'];
    if (clRaw is num) {
      cl = clRaw.toDouble();
    } else if (clRaw != null) {
      cl = double.tryParse(clRaw.toString());
    }
    int? cs;
    final csRaw = json['credit_score'];
    if (csRaw is int) {
      cs = csRaw;
    } else if (csRaw != null) {
      cs = int.tryParse(csRaw.toString());
    }
    int? pce;
    final pceRaw = json['primeros_pedidos_contado_entregados'];
    if (pceRaw is int) {
      pce = pceRaw;
    } else if (pceRaw != null) {
      pce = int.tryParse(pceRaw.toString());
    }
    double? cca;
    final ccaRaw = json['credito_consumido_acumulado'];
    if (ccaRaw is num) {
      cca = ccaRaw.toDouble();
    } else if (ccaRaw != null) {
      cca = double.tryParse(ccaRaw.toString());
    }

    final cpaRaw = json['credito_preactivado_por_admin'];
    final cpa = cpaRaw is bool
        ? cpaRaw
        : (cpaRaw?.toString().toLowerCase() == 'true');

    final psmRaw = json['pedidos_suspendidos_morosidad'];
    final psm = psmRaw is bool
        ? psmRaw
        : (psmRaw?.toString().toLowerCase() == 'true');

    return ProfileModel(
      id: json['id']?.toString() ?? '',
      businessName: _text(json['business_name']),
      rif: _text(json['rif']),
      role: _text(json['role']),
      phone: _text(json['phone']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      creditScore: cs,
      creditLimit: cl,
      kycStatus: _text(json['kyc_status']),
      primerosPedidosContadoEntregados: pce,
      creditoConsumidoAcumulado: cca,
      creditoPreactivadoPorAdmin: cpa,
      pedidosSuspendidosMorosidad: psm,
      estado: _text(json['estado']),
      ciudad: _text(json['ciudad']),
      direccion: _text(json['direccion']),
      logoStoragePath: _text(json['logo_storage_path']),
      fiscalMapsUrl: _text(json['fiscal_maps_url']),
      latitude: _asDoubleNullable(json['latitude']),
      longitude: _asDoubleNullable(json['longitude']),
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.tryParse(json['location_updated_at'].toString())
          : null,
      ratingAvgReceived: _asDoubleNullable(json['rating_avg_received']),
      ratingCountReceived: _asIntNullable(json['rating_count_received']),
      ratingAvgReceivedRolling100:
          _asDoubleNullable(json['rating_avg_received_rolling100']),
      ratingCountReceivedRolling100:
          _asIntNullable(json['rating_count_received_rolling100']),
      ratingDimensionsReceivedRolling100:
          RatingDimensionStatModel.mapFromProfileJson(
        json['rating_dimensions_received_rolling100'],
      ),
      ratingAsPayerAvg: _asDoubleNullable(json['rating_as_payer_avg']),
      ratingAsPayerCount: _asIntNullable(json['rating_as_payer_count']),
    );
  }

  static int? _asIntNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _asDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String? _text(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
