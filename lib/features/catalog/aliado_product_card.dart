import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields_section.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

import 'aliado_catalog_categories.dart';
import 'aliado_catalog_layout.dart';
import 'catalog_product_price_display.dart';
import 'favorite_heart_button.dart';
import 'importer_catalog_logo.dart';
import 'importer_catalog_seals.dart';
import 'part_model.dart';
import 'product_detail_screen.dart';
import 'product_warranty_seal.dart';

String _distanceChipLabel(PartModel part) {
  final km = part.distanceKmFromReference;
  if (km == null) return 'Distancia no disponible';
  if (km < 1) {
    final m = (km * 1000).round();
    return 'A $m m';
  }
  return 'A ${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

String _ownerLocationLine(PartModel part) {
  final e = part.ownerEstado?.trim();
  final c = part.ownerCiudad?.trim();
  if ((e == null || e.isEmpty) && (c == null || c.isEmpty)) return '';
  if (e != null && e.isNotEmpty && c != null && c.isNotEmpty) {
    return '$e · $c';
  }
  return e ?? c ?? '';
}

Color _catalogCardBorder() {
  return AppColors.brightness == Brightness.dark
      ? AppColors.borderSubtle
      : const Color(0xFFE2E8F0);
}

/// Ficha de la vitrina aliado: REF de base, USD promocional y datos de compra.
class AliadoProductCard extends StatelessWidget {
  const AliadoProductCard({
    super.key,
    required this.part,
    required this.profile,
    this.compact = false,
    this.showDistanceChips = false,
    this.onTap,
    this.onImporterTap,
  });

  final PartModel part;
  final ProfileModel profile;
  final bool compact;
  final bool showDistanceChips;
  final VoidCallback? onTap;
  final VoidCallback? onImporterTap;

  @override
  Widget build(BuildContext context) {
    final importer = (part.ownerBusinessName ?? '').trim();
    final importerLine = importer.isNotEmpty ? importer : 'Sin proveedor';
    final category = (part.category ?? '').trim();
    final locLine = _ownerLocationLine(part);
    final hasRating =
        part.ownerRatingAvg != null && (part.ownerRatingCount ?? 0) > 0;
    final radius = BorderRadius.circular(AliadoCatalogLayout.cardRadius);
    final shippingIncluded =
        EnvioPolitica.normalize(part.ownerEnvioTipo) == EnvioPolitica.incluido;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Material(
        color: AppColors.card,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: _catalogCardBorder()),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AliadoCatalogLayout.cardPadH,
                AliadoCatalogLayout.cardPadTop,
                AliadoCatalogLayout.cardPadH,
                AliadoCatalogLayout.cardPadBottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: AliadoCatalogLayout.cardImageAspect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: ProductDetailScreen.heroImageTag(part),
                            child: part.coverImageUrl != null &&
                                    part.coverImageUrl!.isNotEmpty
                                ? Image.network(
                                    part.coverImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _placeholder(compact),
                                  )
                                : _placeholder(compact),
                          ),
                          if (part.isCatalogVerified || part.isCatalogFeatured)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: ImporterCatalogSealsRow(
                                verified: part.isCatalogVerified,
                                featured: part.isCatalogFeatured,
                                compact: true,
                                spacing: 4,
                              ),
                            ),
                          if (part.hasWarranty)
                            const Positioned(
                              top: 6,
                              right: 6,
                              child: ProductWarrantySeal(compact: true),
                            ),
                          if (part.variantChoices.isNotEmpty)
                            Positioned(
                              left: 6,
                              top: part.isCatalogVerified ||
                                      part.isCatalogFeatured
                                  ? 32
                                  : 6,
                              child: _VariantOptionsChip(
                                count: part.variantChoices.length,
                              ),
                            ),
                          if (shippingIncluded)
                            const Positioned(
                              left: 6,
                              bottom: 6,
                              right: 36,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _ShippingIncludedChip(),
                                ),
                              ),
                            ),
                          if (profile.isAliado)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: FavoriteHeartButton(
                                productId: part.id,
                                compact: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AliadoCatalogLayout.cardGapImage),
                  SizedBox(
                    height: AliadoCatalogLayout.cardTitleHeight,
                    child: Text(
                      part.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AliadoCatalogLayout.cardGapTight),
                  SizedBox(
                    height: AliadoCatalogLayout.cardCategoryHeight,
                    child: category.isEmpty
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatCatalogCategoryLabel(category),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brand,
                                height: 1.1,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: AliadoCatalogLayout.cardGapTight),
                  SizedBox(
                    height: AliadoCatalogLayout.cardSupplierHeight,
                    child: InkWell(
                      onTap: onImporterTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          ImporterCatalogLogo(
                            storagePath: part.ownerLogoStoragePath,
                            size: 14,
                          ),
                          if (part.ownerLogoStoragePath?.trim().isNotEmpty ==
                              true)
                            const SizedBox(width: 4),
                          if (hasRating) ...[
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Colors.amber.shade800,
                            ),
                            Text(
                              part.ownerRatingAvg!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              ' · ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              importerLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: onImporterTap != null
                                    ? AppColors.brand
                                    : AppColors.textSecondary,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!compact && locLine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      locLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.1,
                      ),
                    ),
                  ],
                  if (showDistanceChips) ...[
                    const SizedBox(height: AliadoCatalogLayout.cardGapTight),
                    SizedBox(
                      height: AliadoCatalogLayout.cardDistanceHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _distanceChipLabel(part),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AliadoCatalogLayout.cardGapSection),
                  SizedBox(
                    height: AliadoCatalogLayout.cardPriceHeight,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: CatalogProductPriceDisplay(
                        listPriceUsd: part.precio,
                        salePriceUsd: part.salePriceUsd,
                        discountRules: part.discountRules,
                        campaignDiscountPercent:
                            part.activeCampaignDiscountPercent,
                        catalogGrid: true,
                        compact: true,
                        showPromotionChips: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: AliadoCatalogLayout.cardGapTight),
                  SizedBox(
                    height: AliadoCatalogLayout.cardStockHeight,
                    child: _StockLine(part: part),
                  ),
                  const SizedBox(height: AliadoCatalogLayout.cardGapTight),
                  SizedBox(
                    height: AliadoCatalogLayout.cardCustomFieldsHeight,
                    child: ProductCustomFieldsAliadoChips(
                      customFields: part.customFields,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(bool compact) {
    return ColoredBox(
      color: AppColors.surfaceTinted,
      child: Icon(
        Icons.image_outlined,
        size: compact ? 28 : 34,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _StockLine extends StatelessWidget {
  const _StockLine({required this.part});

  final PartModel part;

  @override
  Widget build(BuildContext context) {
    final inStock = part.stockForSale >= part.minOrderQtyEffective;
    final stockColor =
        inStock ? AppColors.successGreen : const Color(0xFF8A5A00);
    final stockLabel = part.stockForSale < 1
        ? 'Sin stock'
        : '${part.stockForSale} en stock';
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: stockLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: stockColor,
            ),
          ),
          TextSpan(
            text: ' · ${part.minOrderQtyLabelEs}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _VariantOptionsChip extends StatelessWidget {
  const _VariantOptionsChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        '$count opciones',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ShippingIncludedChip extends StatelessWidget {
  const _ShippingIncludedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.successGreen.withOpacity(0.35),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 12,
            color: AppColors.successGreen,
          ),
          SizedBox(width: 3),
          Text(
            'Envío incluido',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.successGreen,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
