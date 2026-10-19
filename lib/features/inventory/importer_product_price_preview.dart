import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';

/// Así ve la tienda el precio, con la misma cascada del catálogo.
class ImporterProductPricePreview extends StatelessWidget {
  const ImporterProductPricePreview({
    super.key,
    required this.listPriceUsd,
    this.salePriceUsd,
    this.quantity = 1,
  });

  final double? listPriceUsd;
  final double? salePriceUsd;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final list = listPriceUsd;
    if (list == null || list < 0) {
      return const SizedBox.shrink();
    }
    final qty = quantity < 1 ? 1 : quantity;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Así lo ve la tienda',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Precio REF es la base. El precio USD aparece solo si hay promoción.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            CatalogProductPriceDisplay(
              listPriceUsd: list,
              salePriceUsd: salePriceUsd,
              quantity: qty,
            ),
          ],
        ),
      ),
    );
  }

}

double? parsePreviewMoney(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}
