import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/features/orders/shared/order_flow_copy/order_actions_flow_copy.dart';

/// Importador: cancelar pedido en gestión con motivo obligatorio.
Future<String?> showImporterCancelarPedidoDialog(
  BuildContext context, {
  required String productName,
}) async {
  final ctrl = TextEditingController();
  final ok = await showAdaptiveAdminSheet<bool>(
    context: context,
    builder: (ctx, _) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              OrderActionsFlowCopy.importadorCancelarTitulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              OrderActionsFlowCopy.importadorCancelarIntro(productName),
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              maxLength: 4000,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: OrderActionsFlowCopy.cancelarMotivoObligatorio,
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(OrderActionsFlowCopy.cancelarVolver),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (ctrl.text.trim().length < 3) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text(OrderActionsFlowCopy.cancelarConfirmar),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  final t = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true) return null;
  if (t.length < 3) return null;
  return t;
}
