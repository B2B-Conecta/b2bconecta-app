import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';

PromoCampaignModel _campaign({
  double? general,
  Map<String, double> overrides = const {},
  List<String> productIds = const ['a', 'b'],
}) {
  final now = DateTime.utc(2026, 10, 1);
  return PromoCampaignModel(
    id: 'c1',
    internalTitle: 'Valla',
    campaignType: PromoCampaignModel.typeBanner,
    imageStoragePath: 'a.jpg',
    imagePublicUrl: 'https://example.com/a.jpg',
    importadorId: 'imp-1',
    productIds: productIds,
    discountPercent: general,
    productDiscountPercents: overrides,
    actionType: PromoCampaignModel.actionOpenProduct,
    startsAt: now,
    endsAt: now,
    priority: 1,
    isActive: true,
  );
}

void main() {
  test('dos productos de la misma valla usan porcentajes distintos', () {
    final campaign = _campaign(general: 5, overrides: {'a': 10, 'b': 20});
    expect(campaign.effectivePercentFor('a'), 10);
    expect(campaign.effectivePercentFor('b'), 20);
    expect(
      ProductCatalogPricing.aliadoUnitUsd(
        listPriceUsd: 100,
        campaignDiscountPercent: campaign.effectivePercentFor('a'),
      ),
      closeTo(90, 0.001),
    );
    expect(
      ProductCatalogPricing.aliadoUnitUsd(
        listPriceUsd: 100,
        campaignDiscountPercent: campaign.effectivePercentFor('b'),
      ),
      closeTo(80, 0.001),
    );
  });

  test('sin porcentaje propio hereda el general', () {
    final campaign = _campaign(general: 5, overrides: {'a': 10});
    expect(campaign.effectivePercentFor('b'), 5);
    expect(
      ProductCatalogPricing.aliadoUnitUsd(
        listPriceUsd: 100,
        campaignDiscountPercent: campaign.effectivePercentFor('b'),
      ),
      closeTo(95, 0.001),
    );
  });

  test('0 explícito no hereda el general', () {
    final campaign = _campaign(general: 5, overrides: {'a': 0});
    expect(campaign.effectivePercentFor('a'), isNull);
    expect(campaign.effectivePercentFor('b'), 5);
    expect(campaign.hasProductDiscount, isTrue);
  });

  test('una valla vieja sin mapa sigue con el general', () {
    final campaign = PromoCampaignModel.fromJson({
      'id': 'c1',
      'internal_title': 'Valla',
      'campaign_type': 'banner',
      'image_storage_path': 'a.jpg',
      'image_public_url': 'https://example.com/a.jpg',
      'importador_id': 'imp-1',
      'product_ids': ['a', 'b'],
      'discount_percent': 8,
      'action_type': 'open_product',
      'starts_at': '2026-10-01T00:00:00Z',
      'ends_at': '2026-11-01T00:00:00Z',
      'priority': 0,
      'is_active': true,
    });
    expect(campaign.productDiscountPercents, isEmpty);
    expect(campaign.effectivePercentFor('a'), 8);
    expect(campaign.effectivePercentFor('b'), 8);
  });

  test('al guardar se conservan el general y el de cada producto', () {
    final campaign = _campaign(
      general: 5,
      overrides: {'a': 12.5, 'b': 0, 'otro': 9},
    );
    final json = campaign.toUpdateJson();
    expect(json['discount_percent'], 5);
    expect(json['product_discount_percents'], {'a': 12.5, 'b': 0});

    final reopened = PromoCampaignModel.fromJson({
      ...json,
      'id': 'c1',
      'starts_at': '2026-10-01T00:00:00Z',
      'ends_at': '2026-11-01T00:00:00Z',
    });
    expect(reopened.discountPercent, 5);
    expect(reopened.effectivePercentFor('a'), 12.5);
    expect(reopened.effectivePercentFor('b'), isNull);
  });

  test('con volumen no se aplica el porcentaje del producto', () {
    final campaign = _campaign(overrides: {'a': 20});
    final unit = ProductCatalogPricing.aliadoUnitUsd(
      listPriceUsd: 100,
      campaignDiscountPercent: campaign.effectivePercentFor('a'),
      discountRules: {
        'volume_tiers': [
          {'min_units': 24, 'percent_discount': 10},
        ],
      },
      quantity: 24,
    );
    expect(unit, closeTo(90, 0.001));
  });
}
