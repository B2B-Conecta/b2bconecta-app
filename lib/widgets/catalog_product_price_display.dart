import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/product_catalog_pricing.dart';

/// Precios aliado en catálogo y ficha (REF principal; divisas solo si aplica).
class CatalogProductPriceDisplay extends StatelessWidget {
  const CatalogProductPriceDisplay({
    super.key,
    required this.listPriceUsd,
    this.salePriceUsd,
    this.discountRules,
    this.quantity = 1,
    required this.faseContado,
    this.compact = false,
    this.catalogGrid = false,
    this.showUsd = true,
    this.showPromotionChips = true,
  });

  final double listPriceUsd;
  final double? salePriceUsd;
  final Map<String, dynamic>? discountRules;
  final int quantity;
  final bool faseContado;
  final bool compact;
  final bool catalogGrid;
  final bool showUsd;
  final bool showPromotionChips;

  bool get _onSale => ProductCatalogPricing.hasDirectSale(
        listPriceUsd: listPriceUsd,
        salePriceUsd: salePriceUsd,
      );

  @override
  Widget build(BuildContext context) {
    if (catalogGrid) return _buildGrid(context);
    return _buildDetail(context);
  }

  Widget _buildGrid(BuildContext context) {
    final refUnit = ProductCatalogPricing.aliadoUnitUsd(
      listPriceUsd: listPriceUsd,
      salePriceUsd: salePriceUsd,
      discountRules: discountRules,
      quantity: quantity,
      faseContado: faseContado,
    );
    final strikeRef = _onSale
        ? ProductCatalogPricing.aliadoUnitRegularListUsd(
            listPriceUsd: listPriceUsd,
            discountRules: discountRules,
            quantity: quantity,
            faseContado: faseContado,
          )
        : null;

    final promoChips = showPromotionChips
        ? CatalogProductOfferChips(
            listPriceUsd: listPriceUsd,
            salePriceUsd: salePriceUsd,
            discountRules: discountRules,
            refUnitUsd: refUnit,
            compact: false,
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _refPriceRow(
          refUnit: refUnit,
          strikeRef: strikeRef,
          refSize: 17,
          strikeSize: 11,
        ),
        // Reserva espacio fijo para promociones y evita tarjetas desproporcionadas.
        SizedBox(
          height: 72,
          child: Align(
            alignment: Alignment.topLeft,
            child: promoChips,
          ),
        ),
      ],
    );
  }

  Widget _buildDetail(BuildContext context) {
    final refUnit = ProductCatalogPricing.aliadoUnitUsd(
      listPriceUsd: listPriceUsd,
      salePriceUsd: salePriceUsd,
      discountRules: discountRules,
      quantity: quantity,
      faseContado: faseContado,
    );
    final strikeRef = _onSale
        ? ProductCatalogPricing.aliadoUnitRegularListUsd(
            listPriceUsd: listPriceUsd,
            discountRules: discountRules,
            quantity: quantity,
            faseContado: faseContado,
          )
        : null;
    final usdPct = ProductCatalogPricing.usdPaymentDiscountPct(discountRules);
    final usdUnit = ProductCatalogPricing.aliadoUnitUsdPaymentLine(
      refUnitUsd: refUnit,
      discountRules: discountRules,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Precio MotoLink',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        _refPriceRow(
          refUnit: refUnit,
          strikeRef: strikeRef,
          refSize: compact ? 20 : 22,
          strikeSize: compact ? 13 : 14,
        ),
        if (showUsd && usdPct != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: Colors.green.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'USD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${usdUnit.toStringAsFixed(2)} · ${usdPct.toStringAsFixed(usdPct.truncateToDouble() == usdPct ? 0 : 1)} % menos que REF',
                        style: TextStyle(
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showPromotionChips) ...[
          const SizedBox(height: 8),
          CatalogProductOfferChips(
            listPriceUsd: listPriceUsd,
            salePriceUsd: salePriceUsd,
            discountRules: discountRules,
            refUnitUsd: refUnit,
            compact: false,
          ),
        ],
      ],
    );
  }

  Widget _refPriceRow({
    required double refUnit,
    required double? strikeRef,
    required double refSize,
    required double strikeSize,
  }) {
    final hasStrike = strikeRef != null && (strikeRef - refUnit).abs() > 0.001;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      runSpacing: 2,
      children: [
        if (hasStrike)
          Text(
            '${strikeRef.toStringAsFixed(2)} REF',
            style: TextStyle(
              fontSize: strikeSize,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        Text(
          '${refUnit.toStringAsFixed(2)} REF',
          style: TextStyle(
            fontSize: refSize,
            fontWeight: FontWeight.w900,
            color: hasStrike ? Colors.green.shade700 : AppColors.brand,
            height: 1.05,
          ),
        ),
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
    required this.refUnitUsd,
    this.compact = false,
  });

  final double listPriceUsd;
  final double? salePriceUsd;
  final Map<String, dynamic>? discountRules;
  final double refUnitUsd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chips = <_OfferChipData>[];

    if (ProductCatalogPricing.hasDirectSale(
      listPriceUsd: listPriceUsd,
      salePriceUsd: salePriceUsd,
    )) {
      chips.add(
        _OfferChipData(
          label: 'Oferta',
          bg: Colors.orange.shade50,
          fg: Colors.orange.shade900,
          border: Colors.orange.shade200,
        ),
      );
    }

    final vol = ProductCatalogPricing.volumeIncentiveChipEs(discountRules);
    if (vol != null) {
      chips.add(
        _OfferChipData(
          label: vol,
          bg: Colors.teal.shade50,
          fg: Colors.teal.shade900,
          border: Colors.teal.shade200,
        ),
      );
    }

    final zelle = ProductCatalogPricing.usdPaymentChipEs(
      refUnitUsd: refUnitUsd,
      discountRules: discountRules,
    );
    if (zelle != null) {
      chips.add(
        _OfferChipData(
          label: zelle,
          bg: Colors.green.shade50,
          fg: Colors.green.shade900,
          border: Colors.green.shade200,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: chips.map((c) => _OfferChip(data: c, compact: compact)).toList(),
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
