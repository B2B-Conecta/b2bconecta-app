import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';

void main() {
  test('campaña 5% baja el mayorista sobre lista', () {
    final unit = ProductCatalogPricing.aliadoUnitUsd(
      listPriceUsd: 100,
      campaignDiscountPercent: 5,
    );
    expect(unit, closeTo(95, 0.001));
  });

  test('elige el menor entre oferta directa y campaña', () {
    final unit = ProductCatalogPricing.aliadoUnitUsd(
      listPriceUsd: 100,
      salePriceUsd: 90,
      campaignDiscountPercent: 5,
    );
    expect(unit, closeTo(90, 0.001));
  });

  test('volumen activo ignora la promo y aplica % sobre lista', () {
    final unit = ProductCatalogPricing.aliadoUnitUsd(
      listPriceUsd: 100,
      campaignDiscountPercent: 5,
      discountRules: {
        'volume_tiers': [
          {'min_units': 24, 'percent_discount': 10},
        ],
      },
      quantity: 24,
    );
    // 10% sobre base = 90; no 100*0.95*0.90
    expect(unit, closeTo(90, 0.001));
  });

  test('sin tramo de volumen, promo sobre base', () {
    final unit = ProductCatalogPricing.aliadoUnitUsd(
      listPriceUsd: 100,
      campaignDiscountPercent: 5,
      discountRules: {
        'volume_tiers': [
          {'min_units': 24, 'percent_discount': 10},
        ],
      },
      quantity: 1,
    );
    expect(unit, closeTo(95, 0.001));
  });

  test('chip Promo oculto si el camino volumen está activo', () {
    expect(
      ProductCatalogPricing.campaignDiscountChipEs(
        5,
        discountRules: {
          'volume_tiers': [
            {'min_units': 24, 'percent_discount': 10},
          ],
        },
        quantity: 24,
      ),
      isNull,
    );
  });

  test('chip Promo −5%', () {
    expect(
      ProductCatalogPricing.campaignDiscountChipEs(5),
      'Promo −5%',
    );
  });
}
