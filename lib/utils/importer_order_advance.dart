import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../widgets/importer_transit_eta_dialog.dart';

/// Avanza el estado de una o varias líneas del importador (con ETA si pasa a en tránsito).
Future<bool> advanceImporterOrderGroup(
  BuildContext context, {
  required List<TransactionRequestModel> lines,
  required String nextStatus,
}) async {
  if (lines.isEmpty) return false;

  final messenger = ScaffoldMessenger.maybeOf(context);

  if (nextStatus == TransactionRequestStatus.enTransito) {
    for (final r in lines) {
      if (!r.hasProveedorFactura) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Adjunte la factura del proveedor antes de marcar «En tránsito».',
            ),
          ),
        );
        return false;
      }
    }

    final eta = await showImporterTransitEtaDialog(context);
    if (eta == null) return false;
    if (!context.mounted) return false;

    try {
      for (final r in lines) {
        await SupabaseService.importerMarcaPedidoEnTransito(
          requestId: r.id,
          transitEtaDays: eta.days,
          transitEtaHours: eta.hours,
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      return false;
    }
  }

  try {
    for (final r in lines) {
      await SupabaseService.importerAdvanceTransactionRequest(
        id: r.id,
        newStatus: nextStatus,
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    return false;
  }
}
