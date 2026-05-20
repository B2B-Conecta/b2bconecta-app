import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../utils/admin_order_panel_utils.dart';
import 'admin_compact_party_card.dart';
import 'transaction_request_admin_sections.dart';

/// Cabecera unificada de un carrito admin: aliado, destino (comisión en panel por proveedor).
class AdminCheckoutGroupMasterHeader extends StatelessWidget {
  const AdminCheckoutGroupMasterHeader({
    super.key,
    required this.lines,
  });

  final List<TransactionRequestModel> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final r = lines.first;
    TransactionRequestModel? expLine;
    for (final x in lines) {
      if (x.aliadoExperienceSubmittedAt != null) {
        expLine = x;
        break;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          adminCheckoutGroupResumenLinea(lines),
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lines.first.destinoEntregaLineaCompactaEs,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        AdminCompactAliadoCard(
          profileId: r.aliadoId,
          businessName: r.aliadoBusinessName,
          rif: r.aliadoRif,
          phone: r.aliadoPhone,
          estado: r.aliadoEstado,
          ciudad: r.aliadoCiudad,
          direccion: r.aliadoDireccion,
          fiscalMapsUrl: r.aliadoFiscalMapsUrl,
          logoStoragePath: r.aliadoLogoStoragePath,
          kycStatus: r.aliadoKycStatus,
        ),
        const SizedBox(height: 12),
        TransactionRequestDestinoEntregaSection(request: r),
        if (expLine != null) ...[
          const SizedBox(height: 12),
          TransactionRequestAliadoExperienceAdminSection(request: expLine),
        ],
      ],
    );
  }
}
