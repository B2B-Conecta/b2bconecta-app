import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'product_catalog_pricing.dart';

/// Precios aliado en catálogo y ficha (REF principal; divisas solo si aplica).
class CatalogProductPriceDisplay extends StatelessWidget {
  const CatalogProductPriceDisplay({
    super.key,
    required this.listPriceUsd,
    this.salePriceUsd,
    this.discountRules,
    this.campaignDiscountPercent,
    this.quantity = 1,
    this.compact = false,
    this.catalogGrid = false,
    this.showPromotionChips = true,
    this.usdPromotionView = false,
  });

  final double listPriceUsd;
  final double? salePriceUsd;
  final Map<String, dynamic>? discountRules;
  final double? campaignDiscountPercent;
  final int quantity;
  final bool compact;
  final bool catalogGrid;
  final bool showPromotionChips;

  /// Catálogo aliado: muestra el precio USD de promoción en lugar del REF.
  final bool usdPromotionView;

  bool get _hasUsdPromo => ProductCatalogPricing.hasDirectSale(
        listPriceUsd: listPriceUsd,
        salePriceUsd: salePriceUsd,
      );

  @override
  Widget build(BuildContext context) {
    if (catalogGrid) return _buildGrid(context);
    return _buildDetail(context);
  }

  Widget _buildGrid(BuildContext context) {
    final showUsd = usdPromotionView && _hasUsdPromo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showUsd)
          Text(
            '${salePriceUsd!.toStringAsFixed(2)} USD',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w900,
              color: AppColors.successGreen,
              height: 1.05,
            ),
          ),
        Text(
          '${listPriceUsd.toStringAsFixed(2)} REF',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: showUsd ? (compact ? 11 : 12) : (compact ? 14 : 16),
            fontWeight: showUsd ? FontWeight.w700 : FontWeight.w900,
            color: showUsd ? AppColors.textSecondary : AppColors.brandAccent,
            height: 1.05,
          ),
        ),
        _BasePriceBsLine(
          refUsd: listPriceUsd,
          fontSize: compact ? 11 : 12,
          compact: true,
        ),
        if (showPromotionChips)
          CatalogProductOfferChips(
            listPriceUsd: listPriceUsd,
            salePriceUsd: salePriceUsd,
            discountRules: discountRules,
            campaignDiscountPercent: campaignDiscountPercent,
            quantity: quantity,
            compact: compact,
          ),
      ],
    );
  }

  Widget _buildDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Precio REF',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${listPriceUsd.toStringAsFixed(2)} REF',
          style: TextStyle(
            fontSize: compact ? 20 : 22,
            fontWeight: FontWeight.w900,
            color: AppColors.brandAccent,
            height: 1.05,
          ),
        ),
        if (_hasUsdPromo) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Precio USD',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Promoción',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.successGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${salePriceUsd!.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w900,
              color: AppColors.successGreen,
              height: 1.05,
            ),
          ),
        ],
        _BasePriceBsLine(
          refUsd: listPriceUsd,
          fontSize: compact ? 14 : 16,
        ),
        if (showPromotionChips) ...[
          const SizedBox(height: 8),
          CatalogProductOfferChips(
            listPriceUsd: listPriceUsd,
            salePriceUsd: salePriceUsd,
            discountRules: discountRules,
            campaignDiscountPercent: campaignDiscountPercent,
            quantity: quantity,
            compact: false,
          ),
        ],
      ],
    );
  }
}

/// Chips de oferta / volumen / divisas (catálogo aliado).
class CatalogProductOfferChips extends StatelessWidget {
  const CatalogProductOfferChips({
    super.key,
    required this.listPriceUsd,
    this.salePriceUsd,
    this.discountRules,
    this.campaignDiscountPercent,
    this.quantity = 1,
    this.compact = false,
  });

  final double listPriceUsd;
  final double? salePriceUsd;
  final Map<String, dynamic>? discountRules;
  final double? campaignDiscountPercent;
  final int quantity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chips = <_OfferChipData>[];

    final promoChip = ProductCatalogPricing.campaignDiscountChipEs(
      campaignDiscountPercent,
      discountRules: discountRules,
      quantity: quantity,
    );
    if (promoChip != null) {
      chips.add(
        _OfferChipData(
          label: promoChip,
          bg: const Color(0xFFFFF6E5),
          fg: const Color(0xFF8A5A00),
          border: const Color(0xFFE8A317).withOpacity(0.45),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    final offerChips =
        chips.map((c) => _OfferChip(data: c, compact: compact)).toList();
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          height: 22,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: offerChips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (_, index) => offerChips[index],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: offerChips,
      ),
    );
  }
}

class _OfferChipData {
  const _OfferChipData({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;
}

class _OfferChip extends StatelessWidget {
  const _OfferChip({required this.data, required this.compact});

  final _OfferChipData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: data.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: data.border),
      ),
      child: Text(
        data.label,
        style: TextStyle(
          fontSize: compact ? 10 : 10.5,
          fontWeight: FontWeight.w700,
          color: data.fg,
          height: 1.15,
        ),
      ),
    );
  }
}

/// Bs del precio base REF con la tasa BCV vigente.
class _BasePriceBsLine extends StatefulWidget {
  const _BasePriceBsLine({
    required this.refUsd,
    required this.fontSize,
    this.compact = false,
  });

  /// Siempre el precio REF, no la oferta.
  final double refUsd;
  final double fontSize;
  final bool compact;

  @override
  State<_BasePriceBsLine> createState() => _BasePriceBsLineState();
}

class _BasePriceBsLineState extends State<_BasePriceBsLine> {
  double? _rate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rate = await BcvBasePrice.currentRate();
    if (!mounted) return;
    setState(() => _rate = rate);
  }

  @override
  Widget build(BuildContext context) {
    final bs = BcvBasePrice.bsForRef(widget.refUsd, _rate);
    if (bs == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: widget.compact ? 2 : 4),
      child: Text(
        formatBsLabel(bs),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
