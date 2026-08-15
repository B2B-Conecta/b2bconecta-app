import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/payments/aliado_pago_frecuente_model.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/payments/broker_pricing.dart';

class PaymentsService {
  PaymentsService._();

  static double get logisticFeeRate => BrokerPricing.feeRate;

  static double calculateAliadoUnitPrice(double precioUnitarioProveedor) {
    return BrokerPricing.unitPriceForAliado(precioUnitarioProveedor);
  }

  static Future<void> importadorSetAcceptedPagoMetodos(
    List<String> metodos,
  ) async {
    await SupabaseAccess.client.rpc(
      'importador_set_accepted_pago_metodos',
      params: <String, dynamic>{'p_metodos': metodos},
    );
  }

  /// Importador: solo pagos en divisas/USD (quita Bs y descuentos línea USD del catálogo).
  static Future<void> importadorSetPagoSoloDivisas(bool enabled) async {
    await SupabaseAccess.client.rpc(
      'importador_set_pago_solo_divisas',
      params: <String, dynamic>{'p_enabled': enabled},
    );
  }

  /// Importador: actualización masiva de `usd_payment_discount_pct` en productos.
  /// [scope]: `con_descuento` (solo con % previo) o `todos`.
  static Future<void> importadorSetPagoMetodoInstrucciones(
    Map<String, String> instrucciones,
  ) async {
    await SupabaseAccess.client.rpc(
      'importador_set_pago_metodo_instrucciones',
      params: <String, dynamic>{
        'p_instrucciones': instrucciones,
      },
    );
  }

  /// Aliado: métodos usados con frecuencia con un importador (atajos de pago).
  static Future<List<AliadoPagoFrecuenteModel>>
      fetchAliadoPagoFrecuenteImportador(String importadorId) async {
    final res = await SupabaseAccess.client.rpc(
      'aliado_list_pago_frecuente_importador',
      params: <String, dynamic>{'p_importador_id': importadorId},
    );
    final list = res as List<dynamic>;
    return list
        .map((row) => AliadoPagoFrecuenteModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .where((e) => e.pagoMetodo.isNotEmpty)
        .toList();
  }

  static Future<String> createSignedUrlForOrderInvoice(
      String storagePath) async {
    return SupabaseAccess.client.storage
        .from(SupabaseAccess.orderInvoicesBucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// Comprobante de pago del aliado (`order-payment-proofs`).
  static Future<String> createSignedUrlForComprobantePago(
      String storagePath) async {
    return SupabaseAccess.client.storage
        .from(SupabaseAccess.orderPaymentProofsBucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// Respaldo fotográfico de cobro en efectivo (mismo bucket; prefijo `efectivo_respaldo_`).
  static Future<String> createSignedUrlForEfectivoRespaldo(
      String storagePath) async {
    return SupabaseAccess.client.storage
        .from(SupabaseAccess.orderPaymentProofsBucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// Aliado: sube foto del comprobante y envía a revisión B2B Conecta.
  static Future<void> aliadoSubmitComprobantePago({
    required String transactionRequestId,
    required String metodo,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use imagen o PDF.');
    }

    var safeBase = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'comprobante.$ext';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/${stamp}_$safeBase';

    final row = await SupabaseAccess.client
        .from('transaction_requests')
        .select('comprobante_pago_storage_path, pago_estado_revision')
        .eq('id', transactionRequestId)
        .eq('aliado_id', uid)
        .maybeSingle();
    if (row != null) {
      final m = Map<String, dynamic>.from(row);
      final pe = m['pago_estado_revision']?.toString().trim();
      if (pe == PagoRevisionEstado.aprobado) {
        throw StateError(
          'El pago ya fue confirmado; no puede modificar el comprobante.',
        );
      }
      final oldPath = m['comprobante_pago_storage_path']?.toString().trim();
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await SupabaseAccess.client.storage
              .from(SupabaseAccess.orderPaymentProofsBucket)
              .remove([oldPath]);
        } catch (_) {}
      }
    }

    final contentType = SupabaseAccess.mimeForProfileDocExtension(ext);
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.orderPaymentProofsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
      await SupabaseAccess.client.rpc(
        'aliado_registra_comprobante_pago',
        params: <String, dynamic>{
          'p_request_id': transactionRequestId,
          'p_metodo': metodo,
          'p_storage_path': path,
          'p_file_name': fileName.trim(),
        },
      );
    } catch (e) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.orderPaymentProofsBucket)
            .remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  /// Aliado: un solo archivo de comprobante aplicado a todas las líneas del mismo carrito
  /// e importador (MotoConecta pago directo, sin plan de cuotas por línea).
  static Future<void> aliadoSubmitComprobantePagoBundle({
    required List<TransactionRequestModel> lines,
    required String metodo,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (lines.length < 2) {
      throw ArgumentError(
          'Se requieren al menos 2 líneas para el comprobante unificado.');
    }
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ids = lines.map((e) => e.id).toList();
    final cg0 = lines.first.checkoutGroupId?.trim() ?? '';
    if (cg0.isEmpty) {
      throw StateError(
        'Las líneas deben compartir el mismo carrito (checkout) para un comprobante único.',
      );
    }
    if (!lines.every((r) => (r.checkoutGroupId?.trim() ?? '') == cg0)) {
      throw StateError('Todas las líneas deben pertenecer al mismo carrito.');
    }
    final imp0 = lines.first.ownerId.trim();
    if (!lines.every((r) => r.ownerId.trim() == imp0)) {
      throw StateError('Todas las líneas deben ser del mismo importador.');
    }
    if (!lines.every((r) => r.aliadoId == uid)) {
      throw StateError('No autorizado para alguna de las líneas.');
    }
    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use imagen o PDF.');
    }

    var safeBase = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'comprobante.$ext';

    final rows = await SupabaseAccess.client
        .from('transaction_requests')
        .select(
            'id, pago_estado_revision, comprobante_pago_storage_path, status')
        .eq('aliado_id', uid)
        .inFilter('id', ids);

    if (rows.length != ids.length) {
      throw StateError('No se encontraron todas las líneas del pedido.');
    }
    for (final m in rows) {
      final map = Map<String, dynamic>.from(m as Map<dynamic, dynamic>);
      if (map['status']?.toString() == TransactionRequestStatus.rechazado) {
        throw StateError('Una de las líneas está rechazada.');
      }
      final pe = map['pago_estado_revision']?.toString().trim();
      if (pe == PagoRevisionEstado.aprobado) {
        throw StateError(
          'El pago ya fue confirmado en una línea; no puede modificar el comprobante.',
        );
      }
    }

    for (final old in rows) {
      final map = Map<String, dynamic>.from(old as Map<dynamic, dynamic>);
      final op = map['comprobante_pago_storage_path']?.toString().trim();
      if (op != null && op.isNotEmpty) {
        try {
          await SupabaseAccess.client.storage
              .from(SupabaseAccess.orderPaymentProofsBucket)
              .remove([op]);
        } catch (_) {}
      }
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final primaryId = lines.first.id;
    final path = '$primaryId/${stamp}_bundle_$safeBase';

    final contentType = SupabaseAccess.mimeForProfileDocExtension(ext);
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.orderPaymentProofsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
      final fname = fileName.trim();
      for (final id in ids) {
        await SupabaseAccess.client.rpc(
          'aliado_registra_comprobante_pago',
          params: <String, dynamic>{
            'p_request_id': id,
            'p_metodo': metodo,
            'p_storage_path': path,
            'p_file_name': fname,
          },
        );
      }
    } catch (e) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.orderPaymentProofsBucket)
            .remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  /// Aliado: declara pago en efectivo sin adjunto obligatorio (importador confirma recepción).
  static Future<void> aliadoDeclaraPagoEfectivo({
    required String transactionRequestId,
  }) async {
    if (SupabaseAccess.currentUserId == null)
      throw StateError('No hay sesión activa.');
    await SupabaseAccess.client.rpc(
      'aliado_declara_pago_efectivo',
      params: <String, dynamic>{'p_request_id': transactionRequestId},
    );
  }

  /// Varias líneas del mismo carrito e importador: declara efectivo en todas.
  static Future<void> aliadoDeclaraPagoEfectivoBundle({
    required List<TransactionRequestModel> lines,
  }) async {
    if (lines.isEmpty) return;
    if (lines.length == 1) {
      await aliadoDeclaraPagoEfectivo(transactionRequestId: lines.first.id);
      return;
    }
    for (final r in lines) {
      await aliadoDeclaraPagoEfectivo(transactionRequestId: r.id);
    }
  }

  /// Importador: mismo estado de revisión del comprobante en todas las líneas del carrito (mismo comprobante).
  static Future<void> importadorSetPagoRevisionEstadoBundle({
    required List<String> transactionRequestIds,
    required String nuevoEstado,
    String? rechazoNota,
  }) async {
    if (transactionRequestIds.isEmpty) return;
    for (final id in transactionRequestIds) {
      await importadorSetPagoRevisionEstado(
        transactionRequestId: id,
        nuevoEstado: nuevoEstado,
        rechazoNota: rechazoNota,
      );
    }
  }

  /// Importador: aprueba o rechaza el comprobante registrado por el aliado (`importador_set_pago_revision_estado`).
  static Future<void> importadorSetPagoRevisionEstado({
    required String transactionRequestId,
    required String nuevoEstado,
    String? rechazoNota,
  }) async {
    if (SupabaseAccess.currentUserId == null)
      throw StateError('No hay sesión activa.');
    await SupabaseAccess.client.rpc(
      'importador_set_pago_revision_estado',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_nuevo_estado': nuevoEstado,
        'p_rechazo_nota': rechazoNota,
      },
    );
  }

  /// B2B Conecta: sube foto respaldo del cobro en efectivo y registra vía RPC.
  static Future<void> registrarRespaldoCobroEfectivo({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use imagen o PDF.');
    }
    var safeBase = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'respaldo.$ext';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/efectivo_respaldo_${stamp}_$safeBase';

    final contentType = SupabaseAccess.mimeForProfileDocExtension(ext);
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.orderPaymentProofsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
      await SupabaseAccess.client.rpc(
        'registrar_respaldo_cobro_efectivo',
        params: <String, dynamic>{
          'p_request_id': transactionRequestId,
          'p_storage_path': path,
          'p_file_name': fileName.trim(),
        },
      );
    } catch (e) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.orderPaymentProofsBucket)
            .remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> adminAprobarPagoAliado(String requestId) async {
    await SupabaseAccess.client.rpc(
      'admin_aprobar_pago_aliado',
      params: <String, dynamic>{'p_request_id': requestId},
    );
  }

  static Future<void> adminRechazarComprobantePago({
    required String requestId,
    required String nota,
  }) async {
    await SupabaseAccess.client.rpc(
      'admin_rechazar_comprobante_pago',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_nota': nota.trim(),
      },
    );
  }
}
