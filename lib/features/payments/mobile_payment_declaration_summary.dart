import 'package:flutter/material.dart';
import '../../core/utils/ves_amount_format.dart';
import '../orders/shared/transaction_request_model.dart';

/// The supplier sees the same declared details as the customer, once per bundle.
class MobilePaymentDeclarationSummary extends StatelessWidget {
  const MobilePaymentDeclarationSummary({super.key, required this.request});
  final TransactionRequestModel request;
  @override
  Widget build(BuildContext context) {
    final data = request.pagoDeclaracion;
    if (data.isEmpty || MediaQuery.sizeOf(context).width >= 768) {
      return const SizedBox.shrink();
    }
    final amount = data['amount'], expected = data['expected_amount'];
    final currency = data['currency'] == 'BS' ? 'Bs' : 'USD';
    final different =
        amount is num && expected is num && (amount - expected).abs() > .009;
    final rows = <String>[
      if ((data['reference'] as String? ?? '').isNotEmpty)
        'Referencia: ${data['reference']}',
      if (data['paid_on'] != null) 'Fecha del pago: ${data['paid_on']}',
      if (amount is num)
        'Monto declarado: $currency ${formatRefAmount(amount.toDouble())}',
      if (different)
        'Importe del pedido: $currency ${formatRefAmount(expected.toDouble())} · Revisa la diferencia.',
      if ((data['note'] as String? ?? '').isNotEmpty) 'Nota: ${data['note']}',
    ];
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final row in rows)
            Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(row,
                    style: const TextStyle(fontSize: 12, height: 1.4))),
        ]));
  }
}
