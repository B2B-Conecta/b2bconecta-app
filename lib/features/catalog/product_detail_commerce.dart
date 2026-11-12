import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'catalog_product_price_display.dart';
import 'importer_catalog_logo.dart';
import 'part_model.dart';
import 'product_catalog_pricing.dart';
import 'product_stock_summary.dart';

/// One purchase area keeps the published prices beside the buying conditions.
class ProductDetailPurchaseSummary extends StatelessWidget {
  const ProductDetailPurchaseSummary(
      {super.key, required this.part, this.bcvRate});
  final PartModel part;
  final double? bcvRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DualCurrencyPriceCard(part: part, bcvRate: bcvRate),
        const SizedBox(height: 12),
        ProductStockSummary(part: part, inline: true),
        CatalogProductOfferChips(
          listPriceUsd: part.precio,
          salePriceUsd: part.salePriceUsd,
          discountRules: part.discountRules,
          campaignDiscountPercent: part.activeCampaignDiscountPercent,
          quantity: part.minOrderQtyEffective,
        ),
      ],
    );
  }
}

/// Two-column USD | REF/Bs block matching the detail mockup.
class _DualCurrencyPriceCard extends StatelessWidget {
  const _DualCurrencyPriceCard({required this.part, this.bcvRate});

  final PartModel part;
  final double? bcvRate;

  @override
  Widget build(BuildContext context) {
    final list = part.precio;
    final usd = ProductCatalogPricing.aliadoUnitUsdPaymentLine(
      refUnitUsd: list,
      salePriceUsd: part.salePriceUsd,
      discountRules: part.discountRules,
      ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
    );
    final discount = ProductCatalogPricing.directSaleDiscountChipEs(
        listPriceUsd: list, salePriceUsd: usd);
    final soloDivisas = part.ownerPagoSoloDivisas;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: _PriceColumn(
                  amount: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${usd.toStringAsFixed(2)} USD',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.successGreen,
                          height: 1.15,
                        ),
                      ),
                      if (discount != null) _DetailDiscountChip(label: discount),
                    ],
                  ),
                  caption: 'Pago en divisas',
                ),
              ),
            ),
            if (!soloDivisas) ...[
              VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                  child: _PriceColumn(
                    amount: Text(
                      '${list.toStringAsFixed(2)} REF',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    badge: _BsEquivalent(refUsd: list, rate: bcvRate),
                    caption: 'Pago en Bs al BCV',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailDiscountChip extends StatelessWidget {
  const _DetailDiscountChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F6EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1B7F3A),
          height: 1.1,
        ),
      ),
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({
    required this.amount,
    required this.caption,
    this.badge,
  });

  final Widget amount;
  final Widget? badge;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        amount,
        if (badge != null) ...[const SizedBox(height: 4), badge!],
        const SizedBox(height: 6),
        Text(
          caption,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.2,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _BsEquivalent extends StatefulWidget {
  const _BsEquivalent({required this.refUsd, this.rate});

  final double refUsd;
  final double? rate;

  @override
  State<_BsEquivalent> createState() => _BsEquivalentState();
}

class _BsEquivalentState extends State<_BsEquivalent> {
  double? _rate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _BsEquivalent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate != widget.rate) _load();
  }

  Future<void> _load() async {
    try {
      final rate = widget.rate ?? await BcvBasePrice.currentRate();
      if (!mounted) return;
      setState(() => _rate = rate);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rate = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bs = BcvBasePrice.bsForRef(widget.refUsd, _rate);
    return Text(
      bs == null ? 'Bs …' : formatBsLabel(bs),
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
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
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary.withOpacity(0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImporterCatalogLogo(
                        storagePath: part.ownerLogoStoragePath,
                        size: 36,
                        fallback: LucideIcon(LucideGlyph.store,
                            size: 22, color: primary))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      if (location.isNotEmpty || hasRating) ...[
                        const SizedBox(height: 4),
                        Wrap(spacing: 10, runSpacing: 3, children: [
                          if (location.isNotEmpty)
                            Text(location,
                                style: TextStyle(
                                    fontSize: 13,
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
                                      LucideIcon(LucideGlyph.star,
                                          size: 16, color: starColor),
                                      const SizedBox(width: 3),
                                      Text(
                                          part.ownerRatingAvg!
                                              .toStringAsFixed(1),
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary)),
                                      Text(' (${part.ownerRatingCount})',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary)),
                                    ]),
                              ),
                            ),
                        ]),
                      ],
                      if (onOpen != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Ver tienda',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primary)),
                            LucideIcon(LucideGlyph.chevronRight,
                                size: 17, color: primary),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
