import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/utils/stored_file_page.dart';

import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/orders/shared/order_flow_copy/order_payment_flow_copy.dart';
import 'package:motolink_pro_app/features/orders/shared/b2b_order_panel_widgets.dart';

/// Factura que adjunta el importador; el aliado la revisa antes de pagar.
class AliadoImportadorFacturaSection extends StatelessWidget {
  const AliadoImportadorFacturaSection({
    super.key,
    required this.lines,
    this.compact = false,
  });

  final List<TransactionRequestModel> lines;
  final bool compact;

  TransactionRequestModel? get _ref {
    for (final r in lines) {
      if (r.hasProveedorFactura) return r;
    }
    return null;
  }

  Future<void> _abrir(BuildContext context, String path) {
    return openStoredFile(
      context,
      signedUrl: () => SupabaseService.createSignedUrlForOrderInvoice(path),
      fileName: _ref?.proveedorFacturaFileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _ref;
    if (r == null) {
      return B2bPanelSectionCard(
        tint: Colors.amber.shade50,
        icon: Icons.receipt_long_outlined,
        title: OrderPaymentFlowCopy.aliadoEsperaFactura,
      );
    }

    final path = r.proveedorFacturaStoragePath!.trim();
    final name = r.proveedorFacturaFileName?.trim();

    return B2bPanelSectionCard(
      tint: Colors.blue.shade50,
      icon: Icons.description_outlined,
      title: 'Factura del importador',
      subtitle: [
        if (name != null && name.isNotEmpty) name,
        if (r.proveedorFacturaSubmittedAt != null)
          'Recibida: ${formatEsShortDateTime(r.proveedorFacturaSubmittedAt)}',
      ].join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: () => _abrir(context, path),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text(OrderPaymentFlowCopy.aliadoVerFactura),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandBlue,
              minimumSize: b2bActionButtonMinSize(context),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              'Revise el monto antes de registrar su pago en la pasarela de abajo.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
