import 'package:flutter/material.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'catalog_product_price_display.dart';
import 'part_model.dart';

/// Reuses the cart's current product and quantity for the unit price preview.
class CatalogCartPrice extends StatelessWidget {
  const CatalogCartPrice(
      {super.key,
      required this.part,
      this.cart,
      this.catalogGrid = true,
      this.compact = true,
      this.prominent = true,
      this.showPromotionChips = false,
      this.bcvRate});
  final PartModel part;
  final CartService? cart;
  final bool catalogGrid;
  final bool compact;
  final bool prominent;
  final bool showPromotionChips;
  final double? bcvRate;

  @override
  Widget build(BuildContext context) {
    final service = cart ?? CartService.instance;
    return ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          final line = CartProductActions.lineFor(part, service);
          final product = line?.part ?? part;
          return CatalogProductPriceDisplay(
              listPriceUsd: product.precio,
              salePriceUsd: product.salePriceUsd,
              discountRules: product.discountRules,
              campaignDiscountPercent: product.activeCampaignDiscountPercent,
              ownerPagoSoloDivisas: product.ownerPagoSoloDivisas,
              quantity: line?.quantity ?? product.minOrderQtyEffective,
              catalogGrid: catalogGrid,
              compact: compact,
              prominent: prominent,
              showPromotionChips: showPromotionChips,
              bcvRate: bcvRate);
        });
  }
}
