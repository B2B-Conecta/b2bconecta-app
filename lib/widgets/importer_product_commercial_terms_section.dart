import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/product_volume_tiers.dart';
import 'product_usd_payment_discount_field.dart';
import 'product_volume_tiers_editor.dart';

/// Bloque visible en ficha importador: oferta, volumen y % descuento línea USD.
class ImporterProductCommercialTermsSection extends StatelessWidget {
  const ImporterProductCommercialTermsSection({
    super.key,
    required this.salePriceController,
    required this.usdPaymentDiscountController,
    required this.volumeTiers,
    required this.onVolumeTiersChanged,
    this.enabled = true,
  });

  final TextEditingController salePriceController;
  final TextEditingController usdPaymentDiscountController;
  final List<ProductVolumeTier> volumeTiers;
  final ValueChanged<List<ProductVolumeTier>> onVolumeTiersChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.brandOrange.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.brandOrange.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.brandOrange,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Condiciones para aliados',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Oferta, descuento por cantidad y precio en USD que verán en el catálogo.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: salePriceController,
              enabled: enabled,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Precio oferta mayorista (USD)',
                hintText: 'Opcional · menor que precio lista',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            ProductVolumeTiersEditor(
              tiers: volumeTiers,
              onChanged: onVolumeTiersChanged,
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 12),
            ProductUsdPaymentDiscountField(
              controller: usdPaymentDiscountController,
              enabled: enabled,
            ),
          ],
        ),
      ),
    );
  }
}
