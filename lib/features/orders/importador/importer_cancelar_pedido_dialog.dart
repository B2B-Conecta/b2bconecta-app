import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/orders/shared/order_flow_copy/order_actions_flow_copy.dart';

/// Importador: cancelar pedido en gestión con motivo obligatorio.
Future<String?> showImporterCancelarPedidoDialog(
  BuildContext context, {
  required String productName,
}) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text(OrderActionsFlowCopy.importadorCancelarTitulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(OrderActionsFlowCopy.cancelarVolver),
          ),
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
      );
    },
  );
  final t = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true) return null;
  if (t.length < 3) return null;
  return t;
}
