import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

enum AdminDeletePedidoScope { one, checkoutGroup }

Future<bool> confirmAdminDeletePedido(
  BuildContext context, {
  required TransactionRequestModel line,
}) {
  final name = line.productName?.trim();
  final label = (name == null || name.isEmpty) ? 'este pedido' : '«$name»';
  final billed = line.commissionSettlementId != null;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar pedido'),
      content: Text(
        'Se va a borrar $label (${line.statusLabelEs()}). '
        'También se borra su chat y su postventa. No se puede deshacer.'
        '${billed ? ' Esta línea ya está en una factura de comisión; esa factura no se recalcula.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  ).then((value) => value == true);
}

/// Segunda confirmación cuando el carrito tiene otras líneas.
Future<AdminDeletePedidoScope?> confirmAdminDeletePedidoGroup(
  BuildContext context, {
  required List<TransactionRequestModel> siblings,
}) {
  return showDialog<AdminDeletePedidoScope>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hay más pedidos en este carrito'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            siblings.length == 1
                ? 'Además de esta línea, el carrito incluye otro pedido. Puedes borrar solo esta o todo el carrito.'
                : 'Además de esta línea, el carrito incluye ${siblings.length} pedidos. Puedes borrar solo esta o todo el carrito.',
            style: TextStyle(color: AppColors.textPrimary, height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final line in siblings.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${line.productName?.trim().isNotEmpty == true ? line.productName!.trim() : 'Pedido'} · ${line.cantidad} u. · ${TransactionRequestStatus.labelEs(line.status)}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          if (siblings.length > 8)
            Text(
              'y ${siblings.length - 8} más',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, AdminDeletePedidoScope.one),
          child: const Text('Solo este'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
          onPressed: () =>
              Navigator.pop(context, AdminDeletePedidoScope.checkoutGroup),
          child: Text('Todo el carrito (${siblings.length + 1})'),
        ),
      ],
    ),
  );
}
