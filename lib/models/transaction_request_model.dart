import 'pago_metodo.dart';
import 'payment_schedule_model.dart';
import 'pago_revision_estado.dart';
import 'transaction_request_status.dart';
import '../utils/business_calendar.dart';

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
    required this.precioBaseAliadoTotal,
    this.stockDescontadoEn,
    this.notasAdmin,
    this.canceladoPorAliado = false,
    this.aliadoCancelacionMotivo,
    this.anuladoPorMotolink = false,
    this.motolinkAnulacionMotivo,
    this.createdAt,
    this.updatedAt,
    this.atAprobadoAdmin,
    this.atRechazado,
    this.atEnPreparacion,
    this.atPedidoListo,
    this.atEnTransito,
    this.atEntregado,
    this.productName,
    this.productSku,
    this.aliadoBusinessName,
    this.aliadoRif,
    this.aliadoPhone,
    this.aliadoCreditLimit,
    this.aliadoEstado,
    this.aliadoCiudad,
    this.aliadoDireccion,
    this.aliadoFiscalMapsUrl,
    this.ownerBusinessName,
    this.ownerRif,
    this.ownerPhone,
    this.ownerEstado,
    this.ownerCiudad,
    this.ownerDireccion,
    this.ownerFiscalMapsUrl,
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
    this.adminRutaMapsUrl,
    this.creditPlanType,
    this.creditPlanConfirmedAt,
    this.creditMontoBloqueado,
    this.paymentSchedule = const <PaymentScheduleModel>[],
    this.documentTypePreference,
    this.aliadoExperienceStars,
    this.aliadoExperienceComment,
    this.aliadoExperienceSubmittedAt,
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

  /// Total sin recargo por efectivo; [precioTotal] puede incluir +4 % si el método es efectivo.
  final double precioBaseAliadoTotal;

  /// Inventario descontado al emitir la primera factura MotoLink al aliado.
  final DateTime? stockDescontadoEn;

  final String? notasAdmin;
  final bool canceladoPorAliado;
  final String? aliadoCancelacionMotivo;
  final bool anuladoPorMotolink;
  final String? motolinkAnulacionMotivo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? atAprobadoAdmin;
  final DateTime? atRechazado;
  final DateTime? atEnPreparacion;
  final DateTime? atPedidoListo;
  final DateTime? atEnTransito;
  final DateTime? atEntregado;
  final String? productName;
  final String? productSku;
  final String? aliadoBusinessName;
  final String? aliadoRif;
  final String? aliadoPhone;
  /// Límite MotoLink del aliado (`credit_limit`; embed en listados de pedido).
  final double? aliadoCreditLimit;

  /// Ubicación fiscal del aliado (desde `profiles` al listar el pedido).
  final String? aliadoEstado;
  final String? aliadoCiudad;
  final String? aliadoDireccion;
  final String? aliadoFiscalMapsUrl;

  final String? ownerBusinessName;
  final String? ownerRif;
  final String? ownerPhone;
  final String? ownerEstado;
  final String? ownerCiudad;
  final String? ownerDireccion;
  final String? ownerFiscalMapsUrl;

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

  /// URL de Google Maps de la ruta publicada por MotoLink (visible en tránsito).
  final String? adminRutaMapsUrl;

  /// 1 = contado (1 cuota), 2 o 3 cuotas (cada 15 días), fijado por admin en el chat.
  final int? creditPlanType;
  final DateTime? creditPlanConfirmedAt;
  final double? creditMontoBloqueado;
  final List<PaymentScheduleModel> paymentSchedule;

  /// A6: nota de entrega vs factura fiscal; `null` hasta que el aliado elija.
  final String? documentTypePreference;
  final int? aliadoExperienceStars;
  final String? aliadoExperienceComment;
  final DateTime? aliadoExperienceSubmittedAt;

  bool get hasAgreedCreditPlan =>
      creditPlanType != null &&
      creditPlanType! >= 1 &&
      creditPlanType! <= 3 &&
      paymentSchedule.isNotEmpty;

  /// True si la cuota 1 ya tiene comprobante, envío a revisión o no está pendiente: el plan no se puede cambiar.
  bool get creditPlanLockedForAdminReschedule {
    if (!hasAgreedCreditPlan) return false;
    for (final c in paymentSchedule) {
      if (c.installmentIndex != 1) continue;
      if (c.pagoSubmittedAt != null) return true;
      if (c.hasPagoComprobante) return true;
      if (c.pagoEstadoEfectivo != PagoRevisionEstado.pendiente) {
        return true;
      }
      return false;
    }
    return false;
  }

  /// Suma de cuotas ya aprobadas por MotoLink.
  double get montoAprobadoEnPlanCuotas {
    var s = 0.0;
    for (final c in paymentSchedule) {
      if (c.pagoAprobado) s += c.amountUsd;
    }
    return s;
  }

  /// Monto de pedido aún sujeto a pago bajo el plan (total − cuotas aprobadas).
  double? get saldoPendienteRealConPlan {
    if (!hasAgreedCreditPlan) return null;
    return (precioTotal - montoAprobadoEnPlanCuotas).clamp(0.0, 1.0e15);
  }

  int get _etaDaysCoalesced => transitEtaDays ?? 0;
  int get _etaHoursCoalesced => transitEtaHours ?? 0;

  /// Hay al menos un día o una hora de ETA registrada.
  bool get hasTransitEta =>
      _etaDaysCoalesced > 0 || _etaHoursCoalesced > 0;

  bool get hasAdminRutaMapsUrl =>
      adminRutaMapsUrl != null && adminRutaMapsUrl!.trim().isNotEmpty;

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

  /// Con factura MotoLink hace falta elegir nota vs factura fiscal antes de pagar.
  bool get aliadoDebeElegirDocumentTypeAntesDePago =>
      hasFacturaAliado &&
      (documentTypePreference == null || documentTypePreference!.trim().isEmpty);

  bool get hasComprobantePago =>
      comprobantePagoStoragePath != null &&
      comprobantePagoStoragePath!.trim().isNotEmpty;

  bool get hasEfectivoRespaldo =>
      efectivoRespaldoStoragePath != null &&
      efectivoRespaldoStoragePath!.trim().isNotEmpty;

  /// Hay factura MotoLink y/o comprobante para mostrar (p. ej. como referencia con pedido entregado).
  bool get tieneDocumentacionFacturaPago =>
      hasFacturaAliado || hasComprobantePago;

  /// Pedido entregado, con factura MotoLink, y el pago aún no fue aprobado por MotoLink.
  bool get pagoMotolinkPendienteTrasEntrega {
    if (status != TransactionRequestStatus.entregado) return false;
    if (!hasFacturaAliado) return false;
    final pe = pagoEstadoRevision?.trim();
    if (pe == PagoRevisionEstado.aprobado) return false;
    return true;
  }

  /// En tránsito con factura pero pago sin aprobar (aviso antes de confirmar recepción).
  bool get pagoMotolinkPendienteEnTransito {
    if (status != TransactionRequestStatus.enTransito) return false;
    if (!hasFacturaAliado) return false;
    final pe = pagoEstadoRevision?.trim();
    if (pe == PagoRevisionEstado.aprobado) return false;
    return true;
  }

  /// Entregado, con factura MotoLink y pago validado por el broker.
  bool get pedidoEntregadoYPagado {
    if (status != TransactionRequestStatus.entregado) return false;
    if (!hasFacturaAliado) return false;
    return pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado;
  }

  /// Tras entrega, pago aún no aprobado y ya transcurrieron 3+ días hábiles (excl. sáb/dom) desde el día de entrega.
  bool get pagoPendienteRiesgoCuentaTresDiasHabiles {
    if (!pagoMotolinkPendienteTrasEntrega) return false;
    final at = atEntregado;
    if (at == null) return false;
    return businessDaysElapsedAfterUtcDate(at.toUtc()) >= 3;
  }

  /// Muestra línea MotoLink en ficha de pedido (`credit_limit` > 0).
  bool get muestraCreditoMotoLinkAsignadoEnPedido => (aliadoCreditLimit ?? 0) > 0;

  /// Distingue rechazo inicial, anulación MotoLink (post-aprobación) y cancelación por aliado.
  String statusLabelEs({bool aliadoViewer = false}) {
    if (status == TransactionRequestStatus.rechazado && canceladoPorAliado) {
      return aliadoViewer
          ? 'Cancelada por usted'
          : 'Cancelada por el aliado';
    }
    if (status == TransactionRequestStatus.rechazado && anuladoPorMotolink) {
      return 'Anulada por MotoLink';
    }
    return TransactionRequestStatus.labelEs(status);
  }

  /// Admin puede anular con motivo: aprobado o en curso, no entregado ni pendiente.
  bool get motolinkPuedeAnularComoAdmin {
    return TransactionRequestStatus.adminOperationalActive.contains(status);
  }

  /// Ubicación fiscal del importador (recolección), desde el perfil del owner.
  String? get ownerUbicacionFiscalMultilineaEs {
    final parts = <String>[];
    final e = ownerEstado?.trim();
    final c = ownerCiudad?.trim();
    final d = ownerDireccion?.trim();
    if (e != null && e.isNotEmpty) parts.add(e);
    if (c != null && c.isNotEmpty) parts.add(c);
    if (d != null && d.isNotEmpty) parts.add(d);
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  /// Una línea para URLs de mapas / geocodificación (origen recolección).
  String get ownerUbicacionUnaLineaParaMapa {
    final m = ownerUbicacionFiscalMultilineaEs?.trim();
    if (m != null && m.isNotEmpty) {
      return m.replaceAll('\n', ', ');
    }
    final bn = ownerBusinessName?.trim();
    if (bn != null && bn.isNotEmpty) return bn;
    return 'Almacén importador';
  }

  /// Dirección fiscal del aliado cuando el pedido usa perfil (texto multilínea).
  String? get aliadoDireccionFiscalMultilineaEs {
    if (!destinoEntregaUsaPerfil) return null;
    final parts = <String>[];
    final e = aliadoEstado?.trim();
    final c = aliadoCiudad?.trim();
    final d = aliadoDireccion?.trim();
    if (e != null && e.isNotEmpty) parts.add(e);
    if (c != null && c.isNotEmpty) parts.add(c);
    if (d != null && d.isNotEmpty) parts.add(d);
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  /// Texto de destino de entrega (Bloque A2: fiscal o alternativo).
  String get destinoEntregaTextoParaMapa {
    if (destinoEntregaUsaPerfil) {
      return aliadoDireccionFiscalMultilineaEs?.trim().isNotEmpty == true
          ? aliadoDireccionFiscalMultilineaEs!.replaceAll('\n', ', ')
          : 'Dirección fiscal del aliado';
    }
    final t = destinoEntregaTexto?.trim();
    if (t != null && t.isNotEmpty) return t;
    return 'Destino indicado por el aliado';
  }

  /// Una línea para fichas compactas de pedido.
  String get destinoEntregaLineaCompactaEs {
    if (destinoEntregaUsaPerfil) {
      final e = aliadoEstado?.trim();
      final c = aliadoCiudad?.trim();
      if ((e != null && e.isNotEmpty) || (c != null && c.isNotEmpty)) {
        final bits = <String>[];
        if (e != null && e.isNotEmpty) bits.add(e);
        if (c != null && c.isNotEmpty) bits.add(c);
        return 'Entrega: ${bits.join(' · ')}';
      }
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
      if (status == TransactionRequestStatus.entregado) return null;
      return 'Tras la factura MotoLink al aliado podrá gestionar el pago aquí; no forma parte del cronograma de envío.';
    }
    if (status == TransactionRequestStatus.entregado) {
      if (pagoEstadoRevisionEfectivo == PagoRevisionEstado.aprobado) {
        return 'Entrega confirmada · pago validado por MotoLink.';
      }
      return 'Entrega confirmada · pendiente: comprobante o aprobación de pago por MotoLink.';
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
    if (status == TransactionRequestStatus.enPreparacion ||
        status == TransactionRequestStatus.pedidoListo) {
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

    double? aliadoLim;
    final cl = aliadoMap?['credit_limit'];
    if (cl is num) {
      aliadoLim = cl.toDouble();
    } else if (cl != null) {
      aliadoLim = double.tryParse(cl.toString());
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
      precioBaseAliadoTotal: () {
        final v = json['precio_base_aliado_total'];
        if (v == null) return _asDouble(json['precio_total']);
        return _asDouble(v);
      }(),
      stockDescontadoEn: _parseDate(json['stock_descontado_en']),
      notasAdmin: _nullableText(json['notas_admin']),
      canceladoPorAliado: json['cancelado_por_aliado'] == true,
      aliadoCancelacionMotivo: _nullableText(json['aliado_cancelacion_motivo']),
      anuladoPorMotolink: json['anulado_por_motolink'] == true,
      motolinkAnulacionMotivo: _nullableText(json['motolink_anulacion_motivo']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      atAprobadoAdmin: _parseDate(json['at_aprobado_admin']),
      atRechazado: _parseDate(json['at_rechazado']),
      atEnPreparacion: _parseDate(json['at_en_preparacion']),
      atPedidoListo: _parseDate(json['at_pedido_listo']),
      atEnTransito: _parseDate(json['at_en_transito']),
      atEntregado: _parseDate(json['at_entregado']),
      productName: productName,
      productSku: productSku,
      aliadoBusinessName: _nullableText(aliadoMap?['business_name']),
      aliadoRif: _nullableText(aliadoMap?['rif']),
      aliadoPhone: _nullableText(aliadoMap?['phone']),
      aliadoCreditLimit: aliadoLim,
      aliadoEstado: _nullableText(aliadoMap?['estado']),
      aliadoCiudad: _nullableText(aliadoMap?['ciudad']),
      aliadoDireccion: _nullableText(aliadoMap?['direccion']),
      aliadoFiscalMapsUrl: _nullableText(aliadoMap?['fiscal_maps_url']),
      ownerBusinessName: _nullableText(ownerMap?['business_name']),
      ownerRif: _nullableText(ownerMap?['rif']),
      ownerPhone: _nullableText(ownerMap?['phone']),
      ownerEstado: _nullableText(ownerMap?['estado']),
      ownerCiudad: _nullableText(ownerMap?['ciudad']),
      ownerDireccion: _nullableText(ownerMap?['direccion']),
      ownerFiscalMapsUrl: _nullableText(ownerMap?['fiscal_maps_url']),
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
      adminRutaMapsUrl: _nullableText(json['admin_ruta_maps_url']),
      creditPlanType: _asNullableInt(json['credit_plan_type']),
      creditPlanConfirmedAt: _parseDate(json['credit_plan_confirmed_at']),
      creditMontoBloqueado: _asNullableDouble(json['credit_monto_bloqueado']),
      paymentSchedule: _parsePaymentSchedule(json['payment_schedule']),
      documentTypePreference: _nullableText(json['document_type_preference']),
      aliadoExperienceStars: _asNullableInt(json['aliado_experience_stars']),
      aliadoExperienceComment: _nullableText(json['aliado_experience_comment']),
      aliadoExperienceSubmittedAt:
          _parseDate(json['aliado_experience_submitted_at']),
    );
  }

  static List<PaymentScheduleModel> _parsePaymentSchedule(dynamic v) {
    if (v is! List) return const <PaymentScheduleModel>[];
    final out = v
        .map((e) {
          if (e is! Map) return null;
          return PaymentScheduleModel.fromJson(
            Map<String, dynamic>.from(e),
          );
        })
        .whereType<PaymentScheduleModel>()
        .toList();
    out.sort((a, b) => a.installmentIndex.compareTo(b.installmentIndex));
    return out;
  }

  static int? _asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double? _asNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
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
