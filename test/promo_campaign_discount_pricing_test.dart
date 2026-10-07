import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';

void main() {
  test('campaña 5% baja el mayorista sobre lista', () {
    final unit = ProductCatalogPricing.wholesaleUnitUsd(
      listPriceUsd: 100,
      campaignDiscountPercent: 5,
    );
    expect(unit, closeTo(95, 0.001));
  });

  test('elige el menor entre oferta directa y campaña', () {
    final unit = ProductCatalogPricing.wholesaleUnitUsd(
      listPriceUsd: 100,
      salePriceUsd: 90,
      campaignDiscountPercent: 5,
    );
    expect(unit, closeTo(90, 0.001));
  });

  test('campaña gana si es más baja que la oferta', () {
    final unit = ProductCatalogPricing.wholesaleUnitUsd(
      listPriceUsd: 100,
      salePriceUsd: 98,
      campaignDiscountPercent: 10,
    );
    expect(unit, closeTo(90, 0.001));
  });

  test('chip Promo −5%', () {
    expect(
      ProductCatalogPricing.campaignDiscountChipEs(5),
      'Promo −5%',
    );
  });
}
