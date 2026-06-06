import 'package:flutter/material.dart';

import '../models/pago_metodo.dart';
import '../theme/app_theme.dart';
import '../utils/order_payment_pricing.dart';
import '../utils/ves_amount_format.dart';

/// Banner en la ficha del pedido: descuento divisas al elegir método de pago.
class AliadoUsdPaymentDiscountFichaBanner extends StatelessWidget {
  const AliadoUsdPaymentDiscountFichaBanner({
    super.key,
    required this.preview,
    this.compact = false,
  });

  final UsdPaymentDiscountPreview preview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!preview.applies) return const SizedBox.shrink();

    final pctLabel = preview.pctLabel;
    final metodoLabel = PagoMetodo.labelEs(preview.metodo ?? '');
    final pad = compact
        ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
        : const EdgeInsets.fromLTRB(12, 10, 12, 10);

    return Container(
      width: double.infinity,
      padding: pad,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.savings_outlined,
                size: compact ? 18 : 20,
                color: Colors.green.shade800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descuento por pago en $metodoLabel',
                      style: TextStyle(
                        fontSize: compact ? 11.5 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade900,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          formatRefAmount(preview.baseRef),
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: Colors.grey.shade600,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.grey.shade600,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        Text(
                          '${formatRefAmount(preview.total)} REF',
                          style: TextStyle(
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.green.shade900,
                          ),
                        ),
                        if (pctLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              '−$pctLabel%',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (preview.ahorro > 0.0001) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ahorro: ${formatRefAmount(preview.ahorro)} REF en este pedido',
                        style: TextStyle(
                          fontSize: compact ? 10.5 : 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            const Text(
              'El total se actualiza al registrar el comprobante con este método.',
              style: TextStyle(
                fontSize: 10,
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
