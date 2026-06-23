import 'package:flutter/material.dart';

import '../models/carrier_flete_pago_modo.dart';
import '../models/transaction_request_model.dart';
import '../theme/app_theme.dart';
import '../utils/carrier_eta_format.dart';

/// Importador: transportista elegido por el aliado.
class ImporterOrderCarrierSummarySection extends StatelessWidget {
  const ImporterOrderCarrierSummarySection({
    super.key,
    required this.lines,
  });

  final List<TransactionRequestModel> lines;

  @override
  Widget build(BuildContext context) {
    final withCarrier =
        lines.where((r) => r.hasImporterCarrierSelected).toList();
    if (withCarrier.isEmpty) {
      return Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: Colors.orange.shade900),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Esperando que el aliado seleccione un transportista.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final r = withCarrier.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transportista del aliado',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          r.carrierCompanyName ?? 'Transportista',
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
      ],
    );
  }
}
