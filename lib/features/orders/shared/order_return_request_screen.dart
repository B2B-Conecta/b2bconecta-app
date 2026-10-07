import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'order_motolink_thread_section.dart';
import 'order_return_rules.dart';
import 'transaction_request_model.dart';

/// Pantalla base de devolución. El proceso de estados aún no existe:
/// la evidencia se adjunta en el chat del pedido, aunque el chat normal
/// ya no acepte respuestas porque el pedido está entregado.
class OrderReturnRequestScreen extends StatelessWidget {
  const OrderReturnRequestScreen({
    super.key,
    required this.request,
    required this.allowReplyAsAliado,
    required this.allowReplyAsImportador,
  });

  final TransactionRequestModel request;
  final bool allowReplyAsAliado;
  final bool allowReplyAsImportador;

  @override
  Widget build(BuildContext context) {
    final product = request.productName?.trim();
    final until = OrderReturnRules.availableUntil(request.updatedAt);
    final untilLabel = until == null ? null : formatEsShortDateTime(until.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devoluciones'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              (product == null || product.isEmpty)
                  ? 'Devolución de este pedido'
                  : 'Devolución · $product',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes iniciar la devolución mientras el pedido figura como entregado'
              '${untilLabel == null ? '' : ' y hasta $untilLabel'}. '
              'Adjunta fotos o un video como evidencia en el chat. '
              'La otra parte del pedido recibe el aviso de mensaje nuevo. '
              'Este paso no cambia todavía el estado del pedido.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: OrderMotolinkThreadSection(
                  transactionRequestId: request.id,
                  allowReplyAsAliado: allowReplyAsAliado,
                  allowReplyAsImportador: allowReplyAsImportador,
                  allowReplyAsAdmin: false,
                  suppressBuiltinTitle: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
