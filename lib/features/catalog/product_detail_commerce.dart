import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'catalog_cart_price.dart';
import 'importer_catalog_logo.dart';
import 'part_model.dart';
import 'product_stock_summary.dart';

/// One purchase area keeps the published prices beside the buying conditions.
class ProductDetailPurchaseSummary extends StatelessWidget {
  const ProductDetailPurchaseSummary(
      {super.key, required this.part, this.bcvRate});
  final PartModel part;
  final double? bcvRate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CatalogCartPrice(
                  part: part,
                  catalogGrid: false,
                  compact: false,
                  showPromotionChips: true,
                  bcvRate: bcvRate),
              const SizedBox(height: 10),
              ProductStockSummary(part: part, inline: true),
            ]),
      ),
    );
  }
}

/// A single supplier row replaces repeated company, location and rating blocks.
class ProductDetailSupplier extends StatelessWidget {
  const ProductDetailSupplier({super.key, required this.part, this.onOpen});
  final PartModel part;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final name = part.ownerBusinessName?.trim() ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    final location = [part.ownerEstado, part.ownerCiudad]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final hasRating =
        part.ownerRatingAvg != null && (part.ownerRatingCount ?? 0) > 0;
    final starColor = Colors.amber.shade800;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImporterCatalogLogo(
                      storagePath: part.ownerLogoStoragePath,
                      size: 32,
                      fallback: Icon(Icons.storefront_outlined,
                          size: 22, color: AppColors.textSecondary))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: 'Vendido por ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary)),
                          TextSpan(text: name),
                        ]),
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    if (location.isNotEmpty || hasRating) ...[
                      const SizedBox(height: 3),
                      Wrap(spacing: 10, runSpacing: 3, children: [
                        if (location.isNotEmpty)
                          Text(location,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary)),
                        if (hasRating)
                          Tooltip(
                            message: 'Valoración del proveedor',
                            excludeFromSemantics: true,
                            child: Semantics(
                              label:
                                  'Valoración del proveedor: ${part.ownerRatingAvg!.toStringAsFixed(1)} de 5, ${part.ownerRatingCount} valoraciones',
                              excludeSemantics: true,
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded,
                                        size: 15, color: starColor),
                                    const SizedBox(width: 3),
                                    Text(
                                        part.ownerRatingAvg!.toStringAsFixed(1),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary)),
                                    Text(' (${part.ownerRatingCount})',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary)),
                                  ]),
                            ),
                          ),
                      ]),
                    ],
                  ])),
              if (onOpen != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textSecondary),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
