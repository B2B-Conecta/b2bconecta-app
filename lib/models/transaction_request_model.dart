import 'pago_metodo.dart';
import 'pago_revision_estado.dart';
import 'transaction_request_status.dart';

/// Fila de `transaction_requests` con joins opcionales (producto, aliado, importador).
class TransactionRequestModel {
  const TransactionRequestModel({
    required this.id,
    required this.aliadoId,
    required this.productId,
    required this.ownerId,
    required this.status,
    required this.cantidad,
    required this.precioUnitarioProveedor,
    required this.precioUnitarioAliado,
    required this.precioTotal,
    this.notasAdmin,
    this.createdAt,
    this.updatedAt,
    this.atAprobadoAdmin,
    this.atRechazado,
    this.atEnPreparacion,
    this.atEnTransito,
    this.atEntregado,
    this.productName,
    this.productSku,
    this.aliadoBusinessName,
    this.aliadoRif,
    this.aliadoPhone,
    this.aliadoCreditScore,
    this.ownerBusinessName,
    this.ownerRif,
    this.ownerPhone,
    this.proveedorFacturaStoragePath,
    this.proveedorFacturaFileName,
    this.proveedorFacturaSubmittedAt,
    this.transitEtaDays,
    this.transitEtaHours,
    this.transitEtaSetAt,
    this.facturaAliadoStoragePath,
    this.facturaAliadoFileName,
    this.facturaAliadoSubmittedAt,
    this.pagoMetodo,
    this.comprobantePagoStoragePath,
    this.comprobantePagoFileName,
    this.comprobantePagoSubmittedAt,
    this.pagoEstadoRevision,
    this.pagoComprobanteRechazoNota,
    this.pagoAprobadoAt,
    this.efectivoRespaldoStoragePath,
    this.efectivoRespaldoFileName,
    this.efectivoRespaldoSubmittedAt,
    this.destinoEntregaUsaPerfil = true,
    this.destinoEntregaTexto,
    this.destinoEntregaMapsUrl,
  });

  final String id;
  final String aliadoId;
  final String productId;
  final String ownerId;
  final String status;
  final int cantidad;
  final double precioUnitarioProveedor;
  final double precioUnitarioAliado;
  final double precioTotal;
  final String? notasAdmin;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? atAprobadoAdmin;
  final DateTime? atRechazado;
  final DateTime? atEnPreparacion;
  final DateTime? atEnTransito;
  final DateTime? atEntregado;
  final String? productName;
  final String? productSku;
  final String? aliadoBusinessName;
  final String? aliadoRif;
  final String? aliadoPhone;
  final int? aliadoCreditScore;
  final String? ownerBusinessName;
  final String? ownerRif;
  final String? ownerPhone;

  /// Factura digital del importador (Storage `order-invoices`).
  final String? proveedorFacturaStoragePath;
  final String? proveedorFacturaFileName;
  final DateTime? proveedorFacturaSubmittedAt;

  /// Estimación de tránsito (registra MotoLink al pasar a `en_transito`).
  final int? transitEtaDays;
  final int? transitEtaHours;
  final DateTime? transitEtaSetAt;

  /// Factura oficial MotoLink al aliado (`order-ally-invoices`).
  final String? facturaAliadoStoragePath;
  final String? facturaAliadoFileName;
  final DateTime? facturaAliadoSubmittedAt;

  /// Pago del aliado: método, comprobante (`order-payment-proofs`) y revisión MotoLink.
  final String? pagoMetodo;
  final String? comprobantePagoStoragePath;
  final String? comprobantePagoFileName;
  final DateTime? comprobantePagoSubmittedAt;
  final String? pagoEstadoRevision;
  final String? pagoComprobanteRechazoNota;
  final DateTime? pagoAprobadoAt;

  /// Foto respaldo de cobro en efectivo (`order-payment-proofs`), registra transportista/MotoLink.
  final String? efectivoRespaldoStoragePath;
  final String? efectivoRespaldoFileName;
  final DateTime? efectivoRespaldoSubmittedAt;

  /// Destino de entrega para esta orden (perfil fiscal u otro + Maps opcional).
  final bool destinoEntregaUsaPerfil;
  final String? destinoEntregaTexto;
  final String? destinoEntregaMapsUrl;

  int get _etaDaysCoalesced => transitEtaDays ?? 0;
  int get _etaHoursCoalesced => transitEtaHours ?? 0;

  /// Hay al menos un día o una hora de ETA registrada.
  bool get hasTransitEta =>
      _etaDaysCoalesced > 0 || _etaHoursCoalesced > 0;

  /// Texto breve en español, p. ej. «2 días y 4 horas» o «6 horas».
  String? get transitEtaResumenEs {
    if (!hasTransitEta) return null;
    final parts = <String>[];
    final d = _etaDaysCoalesced;
    final h = _etaHoursCoalesced;
    if (d > 0) {
      parts.add(d == 1 ? '1 día' : '$d días');
    }
    if (h > 0) {
      parts.add(h == 1 ? '1 hora' : '$h horas');
    }
    return parts.join(' y ');
  }

  bool get hasProveedorFactura =>
      proveedorFacturaStoragePath != null &&
      proveedorFacturaStoragePath!.trim().isNotEmpty;

  bool get hasFacturaAliado =>
      facturaAliadoStoragePath != null &&
      facturaAliadoStoragePath!.trim().isNotEmpty;

  bool get hasComprobantePago =>
      comprobantePagoStoragePath != null &&
      comprobantePagoStoragePath!.trim().isNotEmpty;

  bool get hasEfectivoRespaldo =>
      efectivoRespaldoStoragePath != null &&
      efectivoRespaldoStoragePath!.trim().isNotEmpty;

  /// Hay factura MotoLink y/o comprobante para mostrar (p. ej. como referencia con pedido entregado).
  bool get tieneDocumentacionFacturaPago =>
      hasFacturaAliado || hasComprobantePago;

  /// Una línea para fichas compactas de pedido.
  String get destinoEntregaLineaCompactaEs {
    if (destinoEntregaUsaPerfil) {
      return 'Entrega: dirección fiscal del perfil';
    }
    final t = destinoEntregaTexto?.trim();
    if (t != null && t.isNotEmpty) {
      if (t.length <= 48) return 'Entrega: $t';
      return 'Entrega: ${t.substring(0, 46)}…';
    }
    return 'Entrega: otro destino';
  }

  /// `pendiente` si ya hay factura MotoLink pero aún no hay estado persistido.
  String get pagoEstadoRevisionEfectivo {
    if (!hasFacturaAliado) return PagoRevisionEstado.pendiente;
    final r = pagoEstadoRevision?.trim();
    if (r == null || r.isEmpty) return PagoRevisionEstado.pendiente;
    return r;
  }

  /// Mensaje corto para el aliado en fases donde puede declarar o gestionar el pago.
  String? get aliadoPagoEstadoResumenEs {
    if (status == TransactionRequestStatus.rechazado) return null;
    if (!TransactionRequestStatus.aliadoDeclaracionPagoMultietapa.contains(status)) {
      return null;
    }
    if (!hasFacturaAliado) {
      return 'Tras la factura MotoLink al aliado podrá gestionar el pago aquí; no forma parte del cronograma de envío.';
    }
    final metodo = pagoMetodo?.trim();
    if (metodo == PagoMetodo.efectivo) {
      switch (pagoEstadoRevisionEfectivo) {
        case PagoRevisionEstado.pendiente:
          return 'Factura lista · confirme que pagará en efectivo (revisión MotoLink).';
        case PagoRevisionEstado.enRevision:
          return 'Pago en efectivo en revisión por MotoLink.';
        case PagoRevisionEstado.rechazado:
          return 'Declaración no aceptada · puede intentar de nuevo.';
        case PagoRevisionEstado.aprobado:
          return 'Pago en efectivo confirmado · MotoLink marcará el envío en tránsito.';
        default:
          return null;
      }
    }
    if (metodo == PagoMetodo.creditoSistema) {
      switch (pagoEstadoRevisionEfectivo) {
        case PagoRevisionEstado.pendiente:
          return 'Factura lista · solicite el pago con la línea de crédito MotoLink.';
        case PagoRevisionEstado.enRevision:
          return 'Solicitud de crédito en revisión por MotoLink.';
        case PagoRevisionEstado.rechazado:
          return 'Solicitud no aceptada · puede reintentar.';
        case PagoRevisionEstado.aprobado:
          return 'Pago con crédito confirmado · MotoLink marcará el envío en tránsito.';
        default:
          return null;
      }
    }
    switch (pagoEstadoRevisionEfectivo) {
      case PagoRevisionEstado.pendiente:
        return 'Factura lista · realice el pago y adjunte el comprobante.';
      case PagoRevisionEstado.enRevision:
        return 'Comprobante en revisión por MotoLink.';
      case PagoRevisionEstado.rechazado:
        return 'Comprobante no aceptado · puede enviar otro.';
      case PagoRevisionEstado.aprobado:
        return 'Pago aprobado · MotoLink marcará el envío en tránsito.';
      default:
        return null;
    }
  }

  /// Transportista o MotoLink pueden subir foto respaldo si aplica.
  bool get puedeRegistrarRespaldoEfectivo {
    if (pagoMetodo?.trim() != PagoMetodo.efectivo) return false;
    if (hasEfectivoRespaldo) return false;
    if (status == TransactionRequestStatus.enPreparacion) {
      return pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado;
    }
    if (status == TransactionRequestStatus.enTransito) return true;
    if (status == TransactionRequestStatus.entregado) return true;
    return false;
  }

  factory TransactionRequestModel.fromJson(Map<String, dynamic> json) {
    final products = json['products'];
    String? productName;
    String? productSku;
    if (products is Map) {
      final pm = Map<String, dynamic>.from(products);
      productName = pm['name']?.toString();
      final s = pm['sku']?.toString().trim();
      productSku = (s != null && s.isNotEmpty) ? s : null;
    }

    Map<String, dynamic>? aliadoMap;
    final aliadoRaw = json['aliado'];
    if (aliadoRaw is Map) {
      aliadoMap = Map<String, dynamic>.from(aliadoRaw);
    }

    Map<String, dynamic>? ownerMap;
    final ownerRaw = json['owner'];
    if (ownerRaw is Map) {
      ownerMap = Map<String, dynamic>.from(ownerRaw);
    }

    int? credit;
    final cs = aliadoMap?['credit_score'];
    if (cs is int) {
      credit = cs;
    } else if (cs != null) {
      credit = int.tryParse(cs.toString());
    }

    return TransactionRequestModel(
      id: json['id']?.toString() ?? '',
      aliadoId: json['aliado_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pendiente',
      cantidad: _asInt(json['cantidad']),
      precioUnitarioProveedor: _asDouble(json['precio_unitario_proveedor']),
      precioUnitarioAliado: _asDouble(json['precio_unitario_aliado']),
      precioTotal: _asDouble(json['precio_total']),
      notasAdmin: _nullableText(json['notas_admin']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      atAprobadoAdmin: _parseDate(json['at_aprobado_admin']),
      atRechazado: _parseDate(json['at_rechazado']),
      atEnPreparacion: _parseDate(json['at_en_preparacion']),
      atEnTransito: _parseDate(json['at_en_transito']),
      atEntregado: _parseDate(json['at_entregado']),
      productName: productName,
      productSku: productSku,
      aliadoBusinessName: _nullableText(aliadoMap?['business_name']),
      aliadoRif: _nullableText(aliadoMap?['rif']),
      aliadoPhone: _nullableText(aliadoMap?['phone']),
      aliadoCreditScore: credit,
      ownerBusinessName: _nullableText(ownerMap?['business_name']),
      ownerRif: _nullableText(ownerMap?['rif']),
      ownerPhone: _nullableText(ownerMap?['phone']),
      proveedorFacturaStoragePath:
          _nullableText(json['proveedor_factura_storage_path']),
      proveedorFacturaFileName:
          _nullableText(json['proveedor_factura_file_name']),
      proveedorFacturaSubmittedAt: _parseDate(json['proveedor_factura_submitted_at']),
      transitEtaDays: _asNullableInt(json['transit_eta_days']),
      transitEtaHours: _asNullableInt(json['transit_eta_hours']),
      transitEtaSetAt: _parseDate(json['transit_eta_set_at']),
      facturaAliadoStoragePath: _nullableText(json['factura_aliado_storage_path']),
      facturaAliadoFileName: _nullableText(json['factura_aliado_file_name']),
      facturaAliadoSubmittedAt: _parseDate(json['factura_aliado_submitted_at']),
      pagoMetodo: _nullableText(json['pago_metodo']),
      comprobantePagoStoragePath:
          _nullableText(json['comprobante_pago_storage_path']),
      comprobantePagoFileName: _nullableText(json['comprobante_pago_file_name']),
      comprobantePagoSubmittedAt:
          _parseDate(json['comprobante_pago_submitted_at']),
      pagoEstadoRevision: _nullableText(json['pago_estado_revision']),
      pagoComprobanteRechazoNota:
          _nullableText(json['pago_comprobante_rechazo_nota']),
      pagoAprobadoAt: _parseDate(json['pago_aprobado_at']),
      efectivoRespaldoStoragePath:
          _nullableText(json['efectivo_respaldo_storage_path']),
      efectivoRespaldoFileName:
          _nullableText(json['efectivo_respaldo_file_name']),
      efectivoRespaldoSubmittedAt:
          _parseDate(json['efectivo_respaldo_submitted_at']),
      destinoEntregaUsaPerfil: json['destino_entrega_usa_perfil'] != false,
      destinoEntregaTexto: _nullableText(json['destino_entrega_texto']),
      destinoEntregaMapsUrl: _nullableText(json['destino_entrega_maps_url']),
    );
  }

  static int? _asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String? _nullableText(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
