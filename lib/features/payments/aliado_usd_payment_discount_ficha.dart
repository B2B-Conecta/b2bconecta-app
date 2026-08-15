import 'package:flutter/material.dart';

import 'pago_metodo.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/order_payment_pricing.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';

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
        color: AppColors.successGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.35)),
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
                color: AppColors.successGreen,
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
                        color: AppColors.textPrimary,
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
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AppColors.textSecondary,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: AppColors.successGreen,
                        ),
                        Text(
                          '${formatRefAmount(preview.total)} REF',
                          style: TextStyle(
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (pctLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.successGreen.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              '−$pctLabel%',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (preview.ahorro > 0.0001) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ahorro: ${formatRefAmount(preview.ahorro)} REF',
                        style: TextStyle(
                          fontSize: compact ? 10.5 : 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
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
            Text(
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
