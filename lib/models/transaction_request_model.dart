import 'motolink_ally_document_emission_model.dart';
import 'order_item_model.dart';
import 'pago_metodo.dart';
import 'payment_schedule_model.dart';
import 'pago_revision_estado.dart';
import 'sub_order_model.dart';
import 'sub_order_status.dart';
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
    this.aliadoLatitude,
    this.aliadoLongitude,
    this.aliadoLogoStoragePath,
    this.aliadoKycStatus,
    this.ownerBusinessName,
    this.ownerRif,
    this.ownerPhone,
    this.ownerEstado,
    this.ownerCiudad,
    this.ownerDireccion,
    this.ownerFiscalMapsUrl,
    this.ownerLatitude,
    this.ownerLongitude,
    this.ownerLogoStoragePath,
    this.ownerKycStatus,
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
    this.motolinkPendingAutoInvoice = false,
    this.aliadoExperienceStars,
    this.aliadoExperienceComment,
    this.aliadoExperienceSubmittedAt,
    this.isMasterOrder = false,
    this.tasaBcvSnapshot,
    this.subOrders = const <SubOrderModel>[],
    this.importerSubOrderId,
    this.importerViewOrderItems = const <OrderItemModel>[],
    this.motolinkAllyDocumentEmissions = const <MotolinkAllyDocumentEmissionModel>[],
    this.facturaUrl,
    this.checkoutGroupId,
    this.confirmadoPor,
    this.discountRules,
    this.commissionRateSnapshot = 0.05,
    this.comisionDevengadaUsd,
    this.comisionDevengadaAt,
    this.commissionSettlementId,
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
  final double? aliadoLatitude;
  final double? aliadoLongitude;
  final String? aliadoLogoStoragePath;
  final String? aliadoKycStatus;

  final String? ownerBusinessName;
  final String? ownerRif;
  final String? ownerPhone;
  final String? ownerEstado;
  final String? ownerCiudad;
  final String? ownerDireccion;
  final String? ownerFiscalMapsUrl;
  final double? ownerLatitude;
  final double? ownerLongitude;
  final String? ownerLogoStoragePath;
  final String? ownerKycStatus;

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

  /// Foto respaldo de cobro en efectivo (`order-payment-proofs`), registra MotoLink.
  final String? efectivoRespaldoStoragePath;
  final String? efectivoRespaldoFileName;
  final DateTime? efectivoRespaldoSubmittedAt;

  /// Destino de entrega para esta orden (perfil fiscal u otro + Maps opcional).
  final bool destinoEntregaUsaPerfil;
  final String? destinoEntregaTexto;
  final String? destinoEntregaMapsUrl;

  /// URL de Google Maps de la ruta publicada por MotoLink (visible en tránsito).
  final String? adminRutaMapsUrl;

  /// 1 = contado (1 cuota), 2 o 3 cuotas (cada 15 días), acordado por el importador.
  final int? creditPlanType;
  final DateTime? creditPlanConfirmedAt;
  final double? creditMontoBloqueado;
  final List<PaymentScheduleModel> paymentSchedule;

  /// A6: nota de entrega vs factura fiscal; `null` hasta que el aliado elija.
  final String? documentTypePreference;

  /// Cola server-side: generar factura MotoLink al aliado al abrir Pedidos activos (admin).
  final bool motolinkPendingAutoInvoice;
  final int? aliadoExperienceStars;
  final String? aliadoExperienceComment;
  final DateTime? aliadoExperienceSubmittedAt;

  /// Pedido maestro multi-importador (`sub_orders` + `order_items`).
  final bool isMasterOrder;

  /// Tasa BCV fijada al confirmar el pedido (VES por unidad REF). Cálculos de negocio en REF.
  final double? tasaBcvSnapshot;

  final List<SubOrderModel> subOrders;

  /// Si no es null, esta fila representa la vista importador de un sub-pedido concreto.
  final String? importerSubOrderId;

  /// Líneas del sub-pedido del importador (solo en listados por `sub_orders`; ver [orderItemsParaVistaImportador]).
  final List<OrderItemModel> importerViewOrderItems;

  /// Emisiones de documento MotoLink al aliado (nota / factura; puede haber varias hojas).
  final List<MotolinkAllyDocumentEmissionModel> motolinkAllyDocumentEmissions;

  /// URL pública de factura / documento del importador (`transaction_requests.factura_url`).
  final String? facturaUrl;

  /// Varios ítems del mismo carrito comparten este UUID (`transaction_requests.checkout_group_id`).
  final String? checkoutGroupId;

  /// Operador importador que aprueba pago / primera gestión auditada (`transaction_requests.confirmado_por`).
  final String? confirmadoPor;

  /// Tasa MotoLink al checkout (fracción; 0.05 = 5 %).
  final double commissionRateSnapshot;

  /// Comisión devengada al marcar Recibido (Minuta #7 C1).
  final double? comisionDevengadaUsd;
  final DateTime? comisionDevengadaAt;
  final String? commissionSettlementId;

  /// Comisión estimada sobre el total (referencia antes del devengo).
  double get comisionEstimadaUsd =>
      (precioTotal * commissionRateSnapshot * 100).round() / 100;

  bool get comisionDevengada =>
      comisionDevengadaAt != null && (comisionDevengadaUsd ?? 0) > 0;

  /// Reglas comerciales snapshot JSON al checkout (p. ej. tramos por volumen).
  final Map<String, dynamic>? discountRules;

  /// Documentos MotoLink al aliado listos para descarga (finalizados con archivo).
  List<MotolinkAllyDocumentEmissionModel> get motolinkAllyInvoicesDescargables =>
      motolinkAllyDocumentEmissions.where((e) => e.isFinalized).toList();

  /// Pedido con más de una hoja fiscal MotoLink (límite de ítems SENIAT).
  bool get hasMultiFragmentMotolinkAllyDocs =>
      motolinkAllyInvoicesDescargables.any((e) => e.fragmentTotal > 1);

  /// El aliado puede confirmar recepción cuando el pedido está en tránsito o enviado.
  bool get puedeConfirmarRecepcionAliado =>
      status == TransactionRequestStatus.enTransito ||
      status == TransactionRequestStatus.enviado;

  bool get hasAgreedCreditPlan =>
      creditPlanType != null &&
      creditPlanType! >= 1 &&
      creditPlanType! <= 3 &&
      paymentSchedule.isNotEmpty;

  /// True si la cuota 1 ya tiene comprobante, envío a revisión o no está pendiente: el plan no se puede cambiar.
  bool get creditPlanLockedForReschedule => creditPlanLockedForAdminReschedule;

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

  /// Suma de cuotas ya verificadas por el importador.
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
      (facturaAliadoStoragePath != null &&
          facturaAliadoStoragePath!.trim().isNotEmpty) ||
      motolinkAllyDocumentEmissions.any((e) => e.isFinalized);

  /// Negocio nota vs factura fiscal: solo en el chat con el importador (sin selector en app).
  bool get aliadoDebeElegirDocumentTypeAntesDePago => false;

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

  /// En tránsito (o legado enviado) con factura pero pago sin aprobar (aviso antes de confirmar recepción).
  bool get pagoMotolinkPendienteEnTransito {
    if (status != TransactionRequestStatus.enTransito &&
        status != TransactionRequestStatus.enviado) {
      return false;
    }
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

  /// Total pedido en bolívares (solo presentación UI). Fuente de verdad: [precioTotal] en REF.
  double? get precioTotalBsUi =>
      tasaBcvSnapshot != null ? precioTotal * tasaBcvSnapshot! : null;

  /// Aliado: puede cancelar antes de que ningún importador pase de pendiente (y maestro pendiente o aprobado).
  bool get aliadoPuedeCancelarAntesDeGestionImportadores {
    if (!isMasterOrder) {
      return status == TransactionRequestStatus.pendiente;
    }
    if (status != TransactionRequestStatus.pendiente &&
        status != TransactionRequestStatus.aprobadoAdmin) {
      return false;
    }
    if (subOrders.isEmpty) return true;
    return subOrders.every((s) => s.status == SubOrderStatus.pendiente);
  }

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
    if (aliadoViewer && status == TransactionRequestStatus.entregado) {
      return 'Recibido';
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

  /// Texto breve de proveedor(es) importador para la línea de tiempo (p. ej. admin).
  String? get resumenProveedoresLineaTimeline {
    if (isMasterOrder) {
      final names = <String>[];
      final seen = <String>{};
      for (final s in subOrders) {
        final n = s.importadorBusinessName?.trim();
        if (n != null && n.isNotEmpty && !seen.contains(n)) {
          seen.add(n);
          names.add(n);
        }
      }
      if (names.isEmpty) return null;
      if (names.length == 1) return names.first;
      if (names.length == 2) return '${names[0]} · ${names[1]}';
      return '${names[0]} · ${names[1]} +${names.length - 2}';
    }
    final o = ownerBusinessName?.trim();
    if (o != null && o.isNotEmpty) return o;
    return null;
  }

  static int _subOrderStatusRank(String st) {
    switch (st) {
      case SubOrderStatus.pendiente:
        return 0;
      case SubOrderStatus.preparando:
        return 1;
      case SubOrderStatus.listo:
        return 2;
      case SubOrderStatus.enRuta:
        return 3;
      case SubOrderStatus.entregado:
        return 4;
      default:
        return -1;
    }
  }

  int get totalSubOrdersCount => isMasterOrder ? subOrders.length : 0;

  /// Tramos que ya superaron o alcanzaron `preparando`.
  int get subOrdersEnPreparacionOrMoreCount {
    if (!isMasterOrder) return 0;
    return subOrders
        .where((s) => _subOrderStatusRank(s.status) >= _subOrderStatusRank(SubOrderStatus.preparando))
        .length;
  }

  /// Tramos que ya superaron o alcanzaron `listo`.
  int get subOrdersListoOrMoreCount {
    if (!isMasterOrder) return 0;
    return subOrders
        .where((s) => _subOrderStatusRank(s.status) >= _subOrderStatusRank(SubOrderStatus.listo))
        .length;
  }

  String? _resumenImportadoresAtLeast(String minStatus) {
    if (!isMasterOrder || subOrders.isEmpty) return null;
    final minRank = _subOrderStatusRank(minStatus);
    final names = <String>[];
    final seen = <String>{};
    for (final s in subOrders) {
      if (_subOrderStatusRank(s.status) < minRank) continue;
      final n = s.importadorBusinessName?.trim();
      if (n == null || n.isEmpty) continue;
      if (seen.add(n)) names.add(n);
    }
    if (names.isEmpty) return null;
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} · ${names[1]}';
    return '${names[0]} · ${names[1]} +${names.length - 2}';
  }

  /// Importadores que ya marcaron `preparando` (o más).
  String? get resumenImportadoresEnPreparacionOrMore =>
      _resumenImportadoresAtLeast(SubOrderStatus.preparando);

  /// Importadores que ya marcaron `listo` (o más).
  String? get resumenImportadoresListoOrMore =>
      _resumenImportadoresAtLeast(SubOrderStatus.listo);

  /// Suma de unidades en pedido maestro (order_items); en 1:1, [cantidad] de la fila.
  int get totalUnidadesAliado {
    if (!isMasterOrder) return cantidad;
    var t = 0;
    for (final s in subOrders) {
      for (final oi in s.orderItems) {
        t += oi.cantidad;
      }
    }
    return t;
  }

  /// Número de partidas (líneas de producto) en el maestro; 1 en pedido 1:1.
  int get lineasProductoCount {
    if (!isMasterOrder) return 1;
    return subOrders.fold(0, (a, s) => a + s.orderItems.length);
  }

  /// Partidas que debe preparar este importador (API por sub_order o sub_orders del maestro).
  List<OrderItemModel> orderItemsParaVistaImportador(String? importadorUserId) {
    if (importerViewOrderItems.isNotEmpty) return importerViewOrderItems;
    final sid = importerSubOrderId?.trim();
    if (sid != null && sid.isNotEmpty) {
      for (final s in subOrders) {
        if (s.id == sid) return s.orderItems;
      }
    }
    final u = importadorUserId?.trim();
    if (u != null && u.isNotEmpty) {
      for (final s in subOrders) {
        if (s.importadorId == u) return s.orderItems;
      }
    }
    return const <OrderItemModel>[];
  }

  /// Partidas para desglose en pantalla (order_items o datos de la fila).
  List<PedidoProductoLineUi> lineasProductoDesglose({
    String? forImportadorUserId,
  }) {
    final items = orderItemsParaVistaImportador(forImportadorUserId);
    if (items.isNotEmpty) {
      return items.map(PedidoProductoLineUi.fromOrderItem).toList();
    }
    if (isMasterOrder) {
      final uid = forImportadorUserId?.trim();
      final out = <PedidoProductoLineUi>[];
      for (final s in subOrders) {
        if (uid != null &&
            uid.isNotEmpty &&
            s.importadorId.trim() != uid) {
          continue;
        }
        for (final oi in s.orderItems) {
          out.add(PedidoProductoLineUi.fromOrderItem(oi));
        }
      }
      if (out.isNotEmpty) return out;
    }
    final nm = productName?.trim();
    return [
      PedidoProductoLineUi(
        nombre: (nm != null && nm.isNotEmpty) ? nm : 'Producto',
        sku: productSku,
        cantidad: cantidad,
        precioRef: precioTotal,
      ),
    ];
  }

  /// Cabecera corta para fichas importador con desglose por líneas.
  String tituloPedidoImportador(List<OrderItemModel> lines) {
    if (lines.isEmpty) {
      final p = productName?.trim();
      if (p != null && p.isNotEmpty) return p;
      return 'Producto';
    }
    if (lines.length == 1) {
      final n = lines.first.productName?.trim();
      if (n != null && n.isNotEmpty) return n;
      return '1 partida';
    }
    final names = lines
        .map((e) => e.productName?.trim())
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .take(2)
        .toList();
    if (names.length >= 2) {
      return '${names[0]} · ${names[1]}'
          '${lines.length > 2 ? ' +${lines.length - 2}' : ''}';
    }
    if (names.length == 1) return '${names[0]} +${lines.length - 1} más';
    return '${lines.length} partidas';
  }

  int totalUnidadesImportador(List<OrderItemModel> lines) {
    if (lines.isEmpty) return cantidad;
    return lines.fold<int>(0, (a, e) => a + e.cantidad);
  }

  /// Cabecera en listas y resumen: evita «multi-importador» cuando solo hay un almacén (`sub_orders`).
  String get tituloFichaPrincipalPedido {
    if (!isMasterOrder) {
      final p = productName?.trim();
      if (p != null && p.isNotEmpty) return p;
      return 'Producto';
    }
    if (subOrders.isEmpty) {
      return 'Pedido (contenedor)';
    }
    if (subOrders.length > 1) {
      return 'Pedido multi-importador';
    }
    final n = subOrders.first.importadorBusinessName?.trim();
    if (n != null && n.isNotEmpty) {
      return n;
    }
    return 'Un importador';
  }

  /// Nombres de producto en la fila (maestro: todas las partidas en `sub_orders`).
  List<String> get nombresProductosOrdenAliado {
    if (!isMasterOrder) {
      final p = productName?.trim();
      return (p != null && p.isNotEmpty) ? <String>[p] : <String>[];
    }
    final out = <String>[];
    for (final s in subOrders) {
      for (final oi in s.orderItems) {
        final n = oi.productName?.trim();
        if (n != null && n.isNotEmpty) out.add(n);
      }
    }
    return out;
  }

  /// Productos en cabeceras de lista (aliado): nombres reales, no solo el almacén.
  String get etiquetaProductoAliado {
    final names = nombresProductosOrdenAliado;
    if (names.isNotEmpty) {
      if (names.length == 1) return names.first;
      return '${names[0]} · ${names[1]}${names.length > 2 ? ' +${names.length - 2}' : ''}';
    }
    final p = productName?.trim();
    if (p != null && p.isNotEmpty) return p;
    return 'Producto';
  }

  /// Producto(s) en cabeceras de lista (importador): partidas del subpedido o nombre en fila.
  String etiquetaProductoImportador(String? importadorUserId) {
    final lines = orderItemsParaVistaImportador(importadorUserId);
    if (lines.isNotEmpty) {
      return tituloPedidoImportador(lines);
    }
    final p = productName?.trim();
    if (p != null && p.isNotEmpty) return p;
    return 'Producto';
  }

  /// Identificación en el flujo del pedido (importador): **ítem(s)** primero, almacén después.
  String etiquetaGestionLineaImportador(String? importadorUserId) {
    final prod = etiquetaProductoImportador(importadorUserId);
    final imp = ownerBusinessName?.trim();
    if (imp != null && imp.isNotEmpty && imp != prod && !prod.contains(imp)) {
      return '$prod · $imp';
    }
    return prod;
  }

  /// Identificación en el flujo (aliado): **ítem(s) solicitados** primero, importador después.
  String etiquetaGestionLineaAliado() {
    final prod = etiquetaProductoAliado;
    final imp = ownerBusinessName?.trim();
    if (imp != null && imp.isNotEmpty && !prod.contains(imp)) {
      return '$prod · $imp';
    }
    return prod;
  }

  /// Título de estructura para la ficha admin: distingue N importadores vs 1 importador y M productos.
  String get estructuraPedidoAdminBreve {
    if (!isMasterOrder) {
      return 'Un importador · 1 partida (producto único en catálogo)';
    }
    if (subOrders.isEmpty) {
      return 'Contenedor de pedido sin líneas (actualice o revise datos)';
    }
    final nImp = subOrders.length;
    final nLines = lineasProductoCount;
    if (nImp > 1) {
      return 'Varios importadores en un solo pedido: $nImp almacén(es) distintos, '
          '$nLines partida(s) con cantidades.';
    }
    if (nLines > 1) {
      return 'Un importador, varias partidas: 1 almacén, $nLines producto(s) distintos con cantidades.';
    }
    return 'Un importador, una partida: 1 producto y cantidad.';
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

  /// `pendiente` si aún no hay estado persistido en servidor.
  String get pagoEstadoRevisionEfectivo {
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
    if (status == TransactionRequestStatus.entregado) {
      if (pagoEstadoRevisionEfectivo == PagoRevisionEstado.aprobado) {
        return 'Entrega confirmada · pago validado por el importador.';
      }
      return 'Entrega confirmada · pendiente de validación del pago por el importador.';
    }
    if (!hasFacturaAliado) {
      switch (pagoEstadoRevisionEfectivo) {
        case PagoRevisionEstado.pendiente:
          return 'Elija método, pague al importador y adjunte comprobante; el importador verificará la acreditación.';
        case PagoRevisionEstado.enRevision:
          return 'Comprobante en revisión por el importador.';
        case PagoRevisionEstado.rechazado:
          return 'Comprobante no aceptado · puede enviar otro.';
        case PagoRevisionEstado.aprobado:
          return 'Pago confirmado por el importador.';
        default:
          return null;
      }
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

  /// MotoLink puede subir foto respaldo del cobro en efectivo si aplica.
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
    final importadorRaw = json['importador'];
    if (ownerMap == null && importadorRaw is Map) {
      ownerMap = Map<String, dynamic>.from(importadorRaw);
    }

    final cant = _asInt(json['cantidad']);
    final precioTotalVal =
        _asDouble(json['precio_total'] ?? json['precio_total_usd']);
    final unitProv = json['precio_unitario_proveedor'];
    final unitAli = json['precio_unitario_aliado'];
    final unitFallback = cant > 0 ? precioTotalVal / cant : precioTotalVal;
    var precioUnitarioProveedor = _asDouble(unitProv);
    var precioUnitarioAliado = _asDouble(unitAli);
    if (precioUnitarioProveedor == 0 && precioUnitarioAliado == 0) {
      precioUnitarioProveedor = unitFallback;
      precioUnitarioAliado = unitFallback;
    } else if (precioUnitarioProveedor == 0) {
      precioUnitarioProveedor = unitFallback;
    } else if (precioUnitarioAliado == 0) {
      precioUnitarioAliado = unitFallback;
    }

    if ((productName == null || productName.isEmpty) &&
        importadorRaw is Map) {
      final im = Map<String, dynamic>.from(importadorRaw);
      final bn = im['business_name']?.toString().trim();
      productName =
          (bn != null && bn.isNotEmpty) ? 'Pedido · $bn' : 'Pedido';
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
      ownerId: json['owner_id']?.toString() ??
          json['importador_id']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'pendiente',
      cantidad: cant,
      precioUnitarioProveedor: precioUnitarioProveedor,
      precioUnitarioAliado: precioUnitarioAliado,
      precioTotal: precioTotalVal,
      precioBaseAliadoTotal: () {
        final v = json['precio_base_aliado_total'];
        if (v == null) return precioTotalVal;
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
      aliadoLatitude: _asNullableDouble(aliadoMap?['latitude']),
      aliadoLongitude: _asNullableDouble(aliadoMap?['longitude']),
      aliadoLogoStoragePath: _nullableText(aliadoMap?['logo_storage_path']),
      aliadoKycStatus: _nullableText(aliadoMap?['kyc_status']),
      ownerBusinessName: _nullableText(ownerMap?['business_name']),
      ownerRif: _nullableText(ownerMap?['rif']),
      ownerPhone: _nullableText(ownerMap?['phone']),
      ownerEstado: _nullableText(ownerMap?['estado']),
      ownerCiudad: _nullableText(ownerMap?['ciudad']),
      ownerDireccion: _nullableText(ownerMap?['direccion']),
      ownerFiscalMapsUrl: _nullableText(ownerMap?['fiscal_maps_url']),
      ownerLatitude: _asNullableDouble(ownerMap?['latitude']),
      ownerLongitude: _asNullableDouble(ownerMap?['longitude']),
      ownerLogoStoragePath: _nullableText(ownerMap?['logo_storage_path']),
      ownerKycStatus: _nullableText(ownerMap?['kyc_status']),
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
      motolinkPendingAutoInvoice:
          json['motolink_pending_auto_invoice'] == true,
      aliadoExperienceStars: _asNullableInt(json['aliado_experience_stars']),
      aliadoExperienceComment: _nullableText(json['aliado_experience_comment']),
      aliadoExperienceSubmittedAt:
          _parseDate(json['aliado_experience_submitted_at']),
      isMasterOrder: json['is_master_order'] == true,
      tasaBcvSnapshot: _asNullableDouble(json['tasa_bcv_snapshot']),
      subOrders: _parseSubOrders(json['sub_orders']),
      importerSubOrderId: _nullableText(json['_importer_sub_order_id']),
      importerViewOrderItems:
          _parseImporterViewOrderItems(json['_importer_view_order_items']),
      motolinkAllyDocumentEmissions:
          MotolinkAllyDocumentEmissionModel.listFromJson(
        json['motolink_ally_document_emissions'],
      ),
      facturaUrl: _nullableText(json['factura_url']),
      checkoutGroupId: _nullableText(json['checkout_group_id']),
      confirmadoPor: _nullableText(json['confirmado_por']),
      discountRules: () {
        final dr = json['discount_rules'];
        if (dr is Map) return Map<String, dynamic>.from(dr);
        return null;
      }(),
      commissionRateSnapshot: () {
        final v = json['commission_rate_snapshot'];
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '') ?? 0.05;
      }(),
      comisionDevengadaUsd: () {
        final v = json['comision_devengada_usd'];
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }(),
      comisionDevengadaAt: _parseDate(json['comision_devengada_at']),
      commissionSettlementId: _nullableText(json['commission_settlement_id']),
    );
  }

  static List<OrderItemModel> _parseImporterViewOrderItems(dynamic v) {
    if (v is! List) return const <OrderItemModel>[];
    return v
        .map((e) {
          if (e is! Map) return null;
          return OrderItemModel.fromJson(Map<String, dynamic>.from(e));
        })
        .whereType<OrderItemModel>()
        .toList();
  }

  static List<SubOrderModel> _parseSubOrders(dynamic v) {
    if (v is! List) return const <SubOrderModel>[];
    return v
        .map((e) {
          if (e is! Map) return null;
          return SubOrderModel.fromJson(Map<String, dynamic>.from(e));
        })
        .whereType<SubOrderModel>()
        .toList();
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

/// Cabecera compacta: mismo carrito (`checkout_group_id`), varias filas (vista importador).
String tituloCheckoutGrupoImportador(
  List<TransactionRequestModel> lines,
  String? importadorUserId,
) {
  if (lines.isEmpty) return 'Pedido';
  if (lines.length == 1) {
    return lines.single.etiquetaProductoImportador(importadorUserId);
  }
  final labels = <String>[];
  for (final l in lines) {
    final e = l.etiquetaProductoImportador(importadorUserId);
    if (e != 'Producto') labels.add(e);
  }
  if (labels.length >= 2) {
    return '${labels[0]} · ${labels[1]}${lines.length > 2 ? ' +${lines.length - 2}' : ''}';
  }
  if (labels.length == 1) return '${labels[0]} +${lines.length - 1} más';
  return '${lines.length} productos · mismo carrito';
}

/// Cabecera compacta: mismo carrito, varias filas (vista aliado).
String tituloCheckoutGrupoAliado(List<TransactionRequestModel> lines) {
  if (lines.isEmpty) return 'Pedido';
  if (lines.length == 1) return lines.single.etiquetaProductoAliado;
  final labels = lines
      .map((l) => l.etiquetaProductoAliado)
      .where((s) => s != 'Producto')
      .toList();
  if (labels.length >= 2) {
    return '${labels[0]} · ${labels[1]}${lines.length > 2 ? ' +${lines.length - 2}' : ''}';
  }
  if (labels.length == 1) return '${labels[0]} +${lines.length - 1} más';
  return '${lines.length} productos · un carrito';
}

/// Rango del ciclo logístico (alineado con [CourierTimelineWidget]).
int motoconectaEnvioTimelineRank(String status) {
  switch (status) {
    case TransactionRequestStatus.pendiente:
      return 0;
    case TransactionRequestStatus.enPreparacion:
      return 1;
    case TransactionRequestStatus.pedidoListo:
      return 2;
    case TransactionRequestStatus.enTransito:
    case TransactionRequestStatus.enviado:
      return 3;
    case TransactionRequestStatus.entregado:
      return 4;
    case TransactionRequestStatus.rechazado:
      return -1;
    default:
      return 0;
  }
}

/// Misma fase logística en todas las líneas → un solo timeline en la ficha.
/// Trata `en_transito` y `enviado` como equivalentes para no duplicar bloques vacíos.
bool checkoutGroupMismoEstadoEnvio(List<TransactionRequestModel> lines) {
  if (lines.length <= 1) return true;
  if (lines.any((e) => e.status == TransactionRequestStatus.rechazado)) {
    return lines.every((e) => e.status == TransactionRequestStatus.rechazado);
  }
  final rank0 = motoconectaEnvioTimelineRank(lines.first.status);
  return lines.every((e) => motoconectaEnvioTimelineRank(e.status) == rank0);
}
