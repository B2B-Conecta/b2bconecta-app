import 'pago_revision_estado.dart';

/// Corte de cuenta semanal de comisiones MotoLink por importador.
class CommissionSettlementModel {
  const CommissionSettlementModel({
    required this.id,
    required this.importadorId,
    required this.periodStart,
    required this.periodEnd,
    required this.totalCommissionUsd,
    required this.lineCount,
    required this.status,
    this.invoiceReference,
    this.issuedAt,
    this.paidAt,
    this.notes,
    this.createdAt,
    this.importadorBusinessName,
    this.importadorRif,
    this.pagoComprobanteStoragePath,
    this.pagoComprobanteFileName,
    this.pagoComprobanteSubmittedAt,
    this.pagoEstadoRevision,
    this.pagoRechazoNota,
    this.invoicePdfStoragePath,
    this.invoicePdfFileName,
  });

  final String id;
  final String importadorId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalCommissionUsd;
  final int lineCount;
  final String status;
  final String? invoiceReference;
  final DateTime? issuedAt;
  final DateTime? paidAt;
  final String? notes;
  final DateTime? createdAt;
  final String? importadorBusinessName;
  final String? importadorRif;
  final String? pagoComprobanteStoragePath;
  final String? pagoComprobanteFileName;
  final DateTime? pagoComprobanteSubmittedAt;
  final String? pagoEstadoRevision;
  final String? pagoRechazoNota;
  final String? invoicePdfStoragePath;
  final String? invoicePdfFileName;

  bool get tieneFacturaPdf =>
      invoicePdfStoragePath != null &&
      invoicePdfStoragePath!.trim().isNotEmpty;

  bool get isBorrador => status == 'borrador';
  bool get isEmitido => status == 'emitido';
  bool get isPagado => status == 'pagado';
  bool get isAnulado => status == 'anulado';

  bool get tieneComprobantePago =>
      pagoComprobanteStoragePath != null &&
      pagoComprobanteStoragePath!.trim().isNotEmpty;

  bool get pagoEnRevision =>
      pagoEstadoRevision?.trim() == PagoRevisionEstado.enRevision;

  bool get pagoRechazado =>
      pagoEstadoRevision?.trim() == PagoRevisionEstado.rechazado;

  bool get importadorPuedeRegistrarPago =>
      isEmitido &&
      !pagoEnRevision &&
      (pagoEstadoRevision == null ||
          pagoEstadoRevision == PagoRevisionEstado.pendiente ||
          pagoRechazado);

  static String statusLabelEs(String status) {
    switch (status) {
      case 'borrador':
        return 'Borrador';
      case 'emitido':
        return 'Factura emitida';
      case 'pagado':
        return 'Pagado';
      case 'anulado':
        return 'Anulado';
      default:
        return status;
    }
  }

  String get periodLabelEs {
    final s = periodStart;
    final e = periodEnd;
    return '${s.day.toString().padLeft(2, '0')}/${s.month.toString().padLeft(2, '0')}/${s.year}'
        ' — ${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}/${e.year}';
  }

  factory CommissionSettlementModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime(1970);
      final s = v.toString();
      if (s.length >= 10) {
        return DateTime.tryParse(s) ?? DateTime.tryParse('${s.substring(0, 10)}T00:00:00')!;
      }
      return DateTime.tryParse(s) ?? DateTime(1970);
    }

    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    Map<String, dynamic>? impMap;
    final imp = json['importador'];
    if (imp is Map) impMap = Map<String, dynamic>.from(imp);

    return CommissionSettlementModel(
      id: json['id']?.toString() ?? '',
      importadorId: json['importador_id']?.toString() ?? '',
      periodStart: parseDate(json['period_start']),
      periodEnd: parseDate(json['period_end']),
      totalCommissionUsd: asDouble(json['total_commission_usd']),
      lineCount: (json['line_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'borrador',
      invoiceReference: json['invoice_reference']?.toString(),
      issuedAt: json['issued_at'] != null
          ? DateTime.tryParse(json['issued_at'].toString())
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : null,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      importadorBusinessName: impMap?['business_name']?.toString(),
      importadorRif: impMap?['rif']?.toString(),
      pagoComprobanteStoragePath:
          json['pago_comprobante_storage_path']?.toString(),
      pagoComprobanteFileName: json['pago_comprobante_file_name']?.toString(),
      pagoComprobanteSubmittedAt: json['pago_comprobante_submitted_at'] != null
          ? DateTime.tryParse(json['pago_comprobante_submitted_at'].toString())
          : null,
      pagoEstadoRevision: json['pago_estado_revision']?.toString(),
      pagoRechazoNota: json['pago_rechazo_nota']?.toString(),
      invoicePdfStoragePath: json['invoice_pdf_storage_path']?.toString(),
      invoicePdfFileName: json['invoice_pdf_file_name']?.toString(),
    );
  }

  String get pagoEstadoLabelEs {
    final pe = pagoEstadoRevision?.trim();
    if (isPagado || pe == PagoRevisionEstado.aprobado) return 'Pago confirmado';
    if (pe == PagoRevisionEstado.enRevision) return 'Comprobante en revisión';
    if (pe == PagoRevisionEstado.rechazado) return 'Comprobante rechazado';
    if (isEmitido) return 'Pendiente de pago';
    return '';
  }
}

/// Línea de pedido incluida en un corte de comisión.
class CommissionSettlementLineModel {
  const CommissionSettlementLineModel({
    required this.requestId,
    required this.precioTotalUsd,
    required this.comisionDevengadaUsd,
    this.comisionDevengadaAt,
    this.productName,
    this.checkoutGroupId,
  });

  final String requestId;
  final double precioTotalUsd;
  final double comisionDevengadaUsd;
  final DateTime? comisionDevengadaAt;
  final String? productName;
  final String? checkoutGroupId;

  factory CommissionSettlementLineModel.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    String? productName;
    final products = json['products'];
    if (products is Map) {
      productName = products['name']?.toString();
    }

    return CommissionSettlementLineModel(
      requestId: json['id']?.toString() ?? '',
      precioTotalUsd: asDouble(json['precio_total_usd']),
      comisionDevengadaUsd: asDouble(json['comision_devengada_usd']),
      comisionDevengadaAt: json['comision_devengada_at'] != null
          ? DateTime.tryParse(json['comision_devengada_at'].toString())
          : null,
      productName: productName,
      checkoutGroupId: json['checkout_group_id']?.toString(),
    );
  }
}
