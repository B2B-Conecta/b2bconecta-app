import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/logistics/carrier_decision.dart';
import 'transaction_request_model.dart';
import 'transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'order_flow_copy/order_actions_flow_copy.dart';
import 'order_flow_copy/order_payment_flow_copy.dart';
import 'order_pickup_flow_copy.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_transit_eta_dialog.dart';

/// Avanza el estado de una o varias líneas del importador (con ETA si pasa a en tránsito).
Future<bool> advanceImporterOrderGroup(
  BuildContext context, {
  required List<TransactionRequestModel> lines,
  required String nextStatus,
}) async {
  if (lines.isEmpty) return false;

  final messenger = ScaffoldMessenger.maybeOf(context);

  for (final r in lines) {
    if (r.qtyAdjustmentPendienteAliado) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(OrderActionsFlowCopy.bloqueoQtyPendiente),
        ),
      );
      return false;
    }
  }

  if (nextStatus == TransactionRequestStatus.enTransito) {
    for (final r in lines) {
      if (!r.hasProveedorFactura) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(OrderPaymentFlowCopy.bloqueoSinFacturaImportador),
          ),
        );
        return false;
      }

      if (r.carrierDecision == CarrierDecision.pending) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(OrderPickupFlowCopy.bloqueoEsperaAliadoTransporte),
          ),
        );
        return false;
      }

      if (!r.hasPickupConfirmed) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(OrderPickupFlowCopy.bloqueoFaltaRecoleccion),
          ),
        );
        return false;
      }

      if (r.carrierDecision == CarrierDecision.selected &&
          !r.hasImporterCarrierSelected) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(OrderPickupFlowCopy.bloqueoFaltaTransportista),
          ),
        );
        return false;
      }

      if (r.carrierDecision == CarrierDecision.selected &&
          r.carrierFletePagoSeparado &&
          !r.hasFleteFactura) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(OrderPaymentFlowCopy.bloqueoSinFacturaFlete),
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
    final ids = lines.map((r) => r.id).toList();
    await SupabaseService.importerAdvanceTransactionRequest(
      id: lines.first.id,
      newStatus: nextStatus,
      batchIds: ids.length > 1 ? ids : null,
    );
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
