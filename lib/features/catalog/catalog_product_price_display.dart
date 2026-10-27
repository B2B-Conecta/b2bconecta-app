import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'product_catalog_pricing.dart';

/// Published prices: promotional USD first, original REF and its Bs equivalent.
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
    this.prominent = false,
    this.ownerPagoSoloDivisas = false,
    this.bcvRate,
  });
  final double listPriceUsd;
  final double? salePriceUsd;
  final Map<String, dynamic>? discountRules;
  final double? campaignDiscountPercent;
  final int quantity;
  final bool compact;
  final bool catalogGrid;
  final bool showPromotionChips;
  final bool prominent;
  final bool ownerPagoSoloDivisas;
  final double? bcvRate;

  @override
  Widget build(BuildContext context) {
    // Keep the published prices distinct. Cart discounts must not relabel the
    // USD offer as REF or replace the base used for the Bs equivalent.
    final ref = listPriceUsd;
    final hasUsdPrice = ProductCatalogPricing.hasDirectSale(
        listPriceUsd: listPriceUsd, salePriceUsd: salePriceUsd);
    final discountLabel = ProductCatalogPricing.directSaleDiscountChipEs(
        listPriceUsd: listPriceUsd, salePriceUsd: salePriceUsd);
    final mainSize = catalogGrid
        ? (prominent ? 20.0 : (compact ? 14.0 : 16.0))
        : (compact ? 20.0 : 22.0);

    Widget amount(double value, String currency, double size, Color color) =>
        Tooltip(
            message: '${value.toStringAsFixed(2)} $currency por unidad',
            excludeFromSemantics: true,
            child: Text('${value.toStringAsFixed(2)} $currency',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: size,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: color)));

    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasUsdPrice) ...[
            Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  amount(
                      salePriceUsd!, 'USD', mainSize, AppColors.successGreen),
                  if (discountLabel != null)
                    _UsdDiscountChip(label: discountLabel),
                ]),
            const SizedBox(height: 4),
            amount(ref, 'REF', compact || catalogGrid ? 13 : 16,
                AppColors.textSecondary),
          ] else
            amount(ref, 'REF', mainSize, AppColors.textPrimary),
          _BasePriceBsLine(
              refUsd: ref,
              fontSize: compact || catalogGrid ? 11 : 12,
              compact: true,
              rate: bcvRate),
          if (showPromotionChips)
            CatalogProductOfferChips(
                listPriceUsd: listPriceUsd,
                salePriceUsd: salePriceUsd,
                discountRules: discountRules,
                campaignDiscountPercent: campaignDiscountPercent,
                quantity: quantity,
                compact: compact),
        ]);
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

class _UsdDiscountChip extends StatelessWidget {
  const _UsdDiscountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.successGreen,
          height: 1.1,
        ),
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
    this.rate,
  });

  /// Original published REF, before any cart discounts.
  final double refUsd;
  final double fontSize;
  final bool compact;
  final double? rate;

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

  @override
  void didUpdateWidget(covariant _BasePriceBsLine oldWidget) {
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
