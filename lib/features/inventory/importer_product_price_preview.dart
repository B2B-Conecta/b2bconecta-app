import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';
import 'product_usd_payment_discount_field.dart';
import 'product_volume_tiers.dart';

/// Así ve la tienda el precio, con la misma cascada del catálogo.
class ImporterProductPricePreview extends StatelessWidget {
  const ImporterProductPricePreview({
    super.key,
    required this.listPriceUsd,
    this.salePriceUsd,
    this.volumeTiers = const [],
    this.usdPaymentDiscountPct,
    this.quantity = 1,
    this.ownerPagoSoloDivisas = false,
  });

  final double? listPriceUsd;
  final double? salePriceUsd;
  final List<ProductVolumeTier> volumeTiers;
  final double? usdPaymentDiscountPct;
  final int quantity;
  final bool ownerPagoSoloDivisas;

  @override
  Widget build(BuildContext context) {
    final list = listPriceUsd;
    if (list == null || list < 0) {
      return const SizedBox.shrink();
    }
    final rules = buildProductDiscountRules(
      volumeTiers: volumeTiers,
      usdPaymentDiscountPct: usdPaymentDiscountPct,
    );
    final qty = quantity < 1 ? 1 : quantity;
    final tiers = [...volumeTiers]
      ..sort((a, b) => a.minUnits.compareTo(b.minUnits));

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
              'Precio de catálogo para $qty unidad(es). Usa la misma cascada de lista, oferta, volumen y línea USD. La ficha no suma un impuesto aparte.',
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
              discountRules: rules,
              quantity: qty,
              ownerPagoSoloDivisas: ownerPagoSoloDivisas,
            ),
            if (tiers.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final tier in tiers)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Desde ${tier.minUnits} uds.: USD ${_tierUnit(list, rules, tier.minUnits).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  double _tierUnit(
    double list,
    Map<String, dynamic>? rules,
    int units,
  ) {
    return ProductCatalogPricing.aliadoUnitUsd(
      listPriceUsd: list,
      salePriceUsd: salePriceUsd,
      discountRules: rules,
      quantity: units,
    );
  }
}

double? parsePreviewMoney(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

double? parsePreviewUsdDiscount(String raw, {required bool pagoSoloDivisas}) {
  if (pagoSoloDivisas) return null;
  return parseUsdPaymentDiscountPctField(raw);
}
