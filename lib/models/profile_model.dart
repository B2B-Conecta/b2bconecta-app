import 'cash_phase_policy.dart';

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
    this.estado,
    this.ciudad,
    this.direccion,
  });

  final String id;
  final String? businessName;
  final String? rif;

  /// `importador`, `aliado`, `administrador` (broker) o `transportista`.
  final String? role;
  final String? phone;
  final DateTime? createdAt;

  /// Riesgo / crédito (solo relevante para aliados en flujo broker).
  final int? creditScore;
  final double? creditLimit;

  /// Verificación documental MotoLink (`pendiente` … `aprobado`); solo aliados.
  final String? kycStatus;

  /// Entregas completadas contadas hacia la fase “primeros 3 pedidos contado” (0–3).
  final int? primerosPedidosContadoEntregados;

  /// Suma de pedidos entregados pagados con `credito_sistema` (tope vs [creditLimit]).
  final double? creditoConsumidoAcumulado;

  /// Estado / ciudad (Venezuela u otro) para catálogo y pedidos.
  final String? estado;
  final String? ciudad;

  /// Domicilio fiscal / dirección de la empresa (`profiles.direccion`).
  final String? direccion;

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

  /// Aliado en fase “primeros pedidos contado” (menos de [CashPhasePolicy.entregasRequeridas] entregas).
  bool get esAliadoEnFaseContado {
    if (role?.trim().toLowerCase() != 'aliado') return false;
    return (primerosPedidosContadoEntregados ?? 0) < CashPhasePolicy.entregasRequeridas;
  }

  /// Cupo mostrado al aliado: en fase contado se trata como 0 (sin línea revolvente).
  double? get limiteCreditoMostradoAliado {
    if (!esAliadoEnFaseContado) return creditLimit;
    return 0;
  }

  /// Disponible revolvente: límite menos crédito ya consumido en entregas a crédito menos suma de pedidos abiertos.
  double? cupoDisponible(double sumaPrecioTotalPedidosAbiertos) {
    final lim = creditLimit;
    if (lim == null) return null;
    final cons = creditoConsumidoAcumulado ?? 0;
    return lim - cons - sumaPrecioTotalPedidosAbiertos;
  }

  /// Datos mínimos para considerar el perfil listo (catálogo / RLS).
  bool get isComplete {
    final r = role?.trim().toLowerCase();
    final hasRole = r == 'importador' ||
        r == 'aliado' ||
        r == 'administrador' ||
        r == 'transportista';
    final base = businessName != null &&
        businessName!.trim().isNotEmpty &&
        rif != null &&
        rif!.trim().isNotEmpty &&
        hasRole;
    if (!base) return false;
    if (r == 'administrador' || r == 'transportista') return true;
    return hasRegisteredLocation;
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
      estado: _text(json['estado']),
      ciudad: _text(json['ciudad']),
      direccion: _text(json['direccion']),
    );
  }

  static String? _text(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
