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
    this.creditoPreactivadoPorAdmin = false,
    this.pedidosSuspendidosMorosidad = false,
    this.estado,
    this.ciudad,
    this.direccion,
    this.logoStoragePath,
    this.fiscalMapsUrl,
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

  /// Admin MotoLink: puede usar línea de crédito aun en fase contado (confianza / historial).
  final bool creditoPreactivadoPorAdmin;

  /// MotoLink suspendió nuevos pedidos por morosidad (entregas con pago sin aprobar).
  final bool pedidosSuspendidosMorosidad;

  /// Cupo asignado y autorizado para usar en la app aunque [esAliadoEnFaseContado].
  bool get puedeUsarLineaCreditoMotoLinkPreactivada {
    final lim = creditLimit;
    return creditoPreactivadoPorAdmin &&
        lim != null &&
        lim > 0;
  }

  /// Estado / ciudad (Venezuela u otro) para catálogo y pedidos.
  final String? estado;
  final String? ciudad;

  /// Domicilio fiscal / dirección de la empresa (`profiles.direccion`).
  final String? direccion;

  /// Logo del negocio en Storage (`profile-logos/{uid}/...`); opcional.
  final String? logoStoragePath;

  /// Enlace público (p. ej. Google Maps) a la ubicación fiscal; opcional.
  final String? fiscalMapsUrl;

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

  /// `true` mientras no haya completado las primeras [CashPhasePolicy.entregasRequeridas] entregas
  /// en modalidad contado (onboarding). Tras esa fase puede seguir pagando al contado (p. ej. efectivo o transferencia)
  /// según las opciones del pedido, además de crédito MotoLink si aplica.
  bool get esAliadoEnFaseContado {
    if (role?.trim().toLowerCase() != 'aliado') return false;
    return (primerosPedidosContadoEntregados ?? 0) < CashPhasePolicy.entregasRequeridas;
  }

  /// Cupo MotoLink asignado y usable (> 0). Sin cupo, el aliado puede seguir pidiendo al contado
  /// (transferencia/efectivo) tras la fase inicial; otros medios y crédito sistema requieren cupo.
  bool get tieneLineaCreditoMotoLink {
    final lim = creditLimit;
    return lim != null && lim > 0;
  }

  /// Resumen de cupo en Créditos admin: solo con línea MotoLink asignada (`credit_limit` > 0).
  bool get debeMostrarCreditoMotoLinkAsignado => tieneLineaCreditoMotoLink;

  /// Cupo mostrado al aliado: en fase contado es 0 salvo [creditoPreactivadoPorAdmin] con cupo asignado.
  double? get limiteCreditoMostradoAliado {
    if (esAliadoEnFaseContado && !creditoPreactivadoPorAdmin) return 0;
    return creditLimit;
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
    );
  }

  static String? _text(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
