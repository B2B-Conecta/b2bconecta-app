import 'pago_revision_estado.dart';

/// Cuota en `payment_schedule` (montos, vencimiento y, si aplica, pago y revisión).
class PaymentScheduleModel {
  const PaymentScheduleModel({
    required this.id,
    required this.transactionRequestId,
    required this.installmentIndex,
    required this.amountUsd,
    required this.dueOn,
    this.pagoMetodo,
    this.pagoComprobanteStoragePath,
    this.pagoComprobanteFileName,
    this.pagoSubmittedAt,
    this.pagoEstadoRevision,
    this.pagoComprobanteRechazoNota,
    this.pagoAprobadoAt,
  });

  final String id;
  final String transactionRequestId;
  final int installmentIndex;
  final double amountUsd;
  final DateTime dueOn;
  final String? pagoMetodo;
  final String? pagoComprobanteStoragePath;
  final String? pagoComprobanteFileName;
  final DateTime? pagoSubmittedAt;
  final String? pagoEstadoRevision;
  final String? pagoComprobanteRechazoNota;
  final DateTime? pagoAprobadoAt;

  String get pagoEstadoEfectivo {
    final e = pagoEstadoRevision?.trim();
    if (e == null || e.isEmpty) return PagoRevisionEstado.pendiente;
    return e;
  }

  bool get pagoAprobado =>
      pagoEstadoEfectivo == PagoRevisionEstado.aprobado;

  bool get hasPagoComprobante =>
      pagoComprobanteStoragePath != null &&
      pagoComprobanteStoragePath!.trim().isNotEmpty;

  factory PaymentScheduleModel.fromJson(Map<String, dynamic> json) {
    return PaymentScheduleModel(
      id: json['id']?.toString() ?? '',
      transactionRequestId: json['transaction_request_id']?.toString() ?? '',
      installmentIndex: _asInt(json['installment_index']),
      amountUsd: _asDouble(json['amount_usd']),
      dueOn: _parseDate(json['due_on']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      pagoMetodo: _nullableText(json['pago_metodo']),
      pagoComprobanteStoragePath: _nullableText(json['pago_comprobante_storage_path']),
      pagoComprobanteFileName: _nullableText(json['pago_comprobante_file_name']),
      pagoSubmittedAt: _parseDate(json['pago_submitted_at']),
      pagoEstadoRevision: _nullableText(json['pago_estado_revision']),
      pagoComprobanteRechazoNota:
          _nullableText(json['pago_comprobante_rechazo_nota']),
      pagoAprobadoAt: _parseDate(json['pago_aprobado_at']),
    );
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
