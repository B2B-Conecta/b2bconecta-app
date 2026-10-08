import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/favorite_heart_button.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/catalog/related_products.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Valoraciones del proveedor. Usa la reputación de pedidos, no una reseña del SKU.
class SupplierRatingBlock extends StatelessWidget {
  const SupplierRatingBlock({
    super.key,
    required this.part,
    this.onOpenStore,
  });

  final PartModel part;
  final VoidCallback? onOpenStore;

  @override
  Widget build(BuildContext context) {
    final name = (part.ownerBusinessName ?? '').trim();
    final avg = part.ownerRatingAvg;
    final count = part.ownerRatingCount ?? 0;
    final hasScore = avg != null && count > 0;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpenStore,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Valoraciones del proveedor',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name.isEmpty ? 'Proveedor' : name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: onOpenStore == null
                      ? AppColors.textSecondary
                      : AppColors.brand,
                ),
              ),
              const SizedBox(height: 4),
              if (hasScore)
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 4),
                    Text(
                      '${avg.toStringAsFixed(1)} / 5 · $count valoraciones',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Este proveedor aún no tiene valoraciones de pedidos.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RelatedProductsSection extends StatelessWidget {
  const RelatedProductsSection({
    super.key,
    required this.current,
    required this.products,
    required this.profile,
  });

  final PartModel current;
  final List<PartModel> products;
  final ProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final showHeart = profile?.isAliado == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          relatedProductsTitle(current),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final part = products[index];
              return _RelatedProductCard(
                part: part,
                showHeart: showHeart,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RelatedProductCard extends StatelessWidget {
  const _RelatedProductCard({
    required this.part,
    required this.showHeart,
  });

  final PartModel part;
  final bool showHeart;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ProductDetailScreen(part: part),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: part.coverImageUrl != null &&
                                part.coverImageUrl!.isNotEmpty
                            ? Image.network(
                                part.coverImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _RelatedPlaceholder(),
                              )
                            : const _RelatedPlaceholder(),
                      ),
                      if (showHeart)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: FavoriteHeartButton(
                            productId: part.id,
                            compact: true,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  part.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                CatalogProductPriceDisplay(
                  listPriceUsd: part.precio,
                  salePriceUsd: part.salePriceUsd,
                  discountRules: part.discountRules,
                  campaignDiscountPercent: part.activeCampaignDiscountPercent,
                  catalogGrid: true,
                  compact: true,
                  showPromotionChips: false,
                  ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RelatedPlaceholder extends StatelessWidget {
  const _RelatedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.borderSubtle,
      child: Icon(
        Icons.precision_manufacturing_outlined,
        color: AppColors.textMuted,
      ),
    );
  }
}
