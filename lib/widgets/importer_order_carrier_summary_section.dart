import 'package:flutter/material.dart';

import '../models/carrier_decision.dart';
import '../models/carrier_flete_pago_modo.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../utils/carrier_eta_format.dart';
import '../utils/order_pickup_flow_copy.dart';
import 'b2b_order_panel_widgets.dart';

/// Importador: paso 1 del flujo (decisión de transporte del aliado).
class ImporterOrderCarrierSummarySection extends StatelessWidget {
  const ImporterOrderCarrierSummarySection({
    super.key,
    required this.lines,
  });

  final List<TransactionRequestModel> lines;

  TransactionRequestModel get _ref => lines.first;

  @override
  Widget build(BuildContext context) {
    final r = _ref;
    if (r.status != TransactionRequestStatus.pedidoListo) {
      return const SizedBox.shrink();
    }

    return switch (r.carrierDecision) {
      CarrierDecision.pending => _banner(
          color: Colors.orange,
          icon: Icons.local_shipping_outlined,
          title: OrderPickupFlowCopy.importadorEsperaAliadoTitulo,
          body: OrderPickupFlowCopy.importadorEsperaAliadoCuerpo,
        ),
      CarrierDecision.skipped => _banner(
          color: Colors.blueGrey,
          icon: Icons.check_circle_outline,
          title: OrderPickupFlowCopy.importadorAliadoSinPlataformaTitulo,
          body: OrderPickupFlowCopy.importadorAliadoSinPlataformaCuerpo,
        ),
      CarrierDecision.selected => _selectedSummary(r),
      CarrierDecision.notApplicable => _banner(
          color: Colors.blueGrey,
          icon: Icons.inventory_2_outlined,
          title: OrderPickupFlowCopy.importadorSinTransportistasTitulo,
          body: OrderPickupFlowCopy.importadorSinTransportistasCuerpo,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _banner({
    required MaterialColor color,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return B2bPanelSectionCard(
      tint: color.shade50,
      icon: icon,
      title: title,
      subtitle: body,
    );
  }

  Widget _selectedSummary(TransactionRequestModel r) {
    if (!r.hasImporterCarrierSelected) {
      return _banner(
        color: Colors.orange,
        icon: Icons.local_shipping_outlined,
        title: OrderPickupFlowCopy.importadorTransportistaPendienteTitulo,
        body: OrderPickupFlowCopy.importadorTransportistaPendienteCuerpo,
      );
    }

    return B2bPanelSectionCard(
      icon: Icons.local_shipping_outlined,
      title: OrderPickupFlowCopy.importadorTransportistaElegidoTitulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.carrierDisplayCompanyName ?? 'Transportista',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            CarrierFletePagoModo.labelEs(r.carrierFletePagoModoSnapshot),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          if (r.carrierFeeUsdSnapshot != null) ...[
            const SizedBox(height: 4),
            Text(
              'Flete estimado: ${CarrierEtaFormat.feeLabel(r.carrierFeeUsdSnapshot)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
          if (!r.hasPickupConfirmed) ...[
            const SizedBox(height: 8),
            Text(
              'Siguiente paso: elija el punto de recolección.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
