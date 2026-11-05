import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';

void main() {
  final legacy = <String, dynamic>{
    'id': 'campaign',
    'internal_title': 'Oferta',
    'display_title': 'Proveedor',
    'campaign_type': 'banner',
    'image_storage_path': 'desktop.jpg',
    'image_public_url': 'https://example.test/desktop.jpg',
    'starts_at': '2026-11-01T00:00:00Z',
    'ends_at': '2026-11-18T00:00:00Z',
    'priority': 1,
    'is_active': true,
  };
  test('existing campaigns use desktop artwork at every viewport width', () {
    for (final parse in [
      PromoCampaignModel.fromJson,
      PromoCampaignModel.fromAliadoRpcJson,
      PromoCampaignModel.fromImportadorRpcJson
    ]) {
      final c = parse(legacy);
      expect(c.imageUrlForWidth(390), legacy['image_public_url']);
      expect(c.imageUrlForWidth(1440), legacy['image_public_url']);
      expect(c.mobileImagePublicUrl, isNull);
    }
  });
  test('all projections select mobile below 600 and desktop on wider layouts',
      () {
    final row = {
      ...legacy,
      'mobile_image_storage_path': 'mobile.jpg',
      'mobile_image_public_url': 'https://example.test/mobile.jpg'
    };
    for (final parse in [
      PromoCampaignModel.fromJson,
      PromoCampaignModel.fromAliadoRpcJson,
      PromoCampaignModel.fromImportadorRpcJson
    ]) {
      final c = parse(row);
      expect(c.imageUrlForWidth(599), row['mobile_image_public_url']);
      expect(c.imageUrlForWidth(600), row['image_public_url']);
      expect(c.imageUrlForWidth(1440), row['image_public_url']);
    }
  });
  test('mobile-only creative still counts as displayable', () {
    final c = PromoCampaignModel.fromAliadoRpcJson({
      'id': 'mobile-only',
      'campaign_type': 'banner',
      'image_public_url': '',
      'mobile_image_public_url': 'https://example.test/mobile.jpg',
      'starts_at': '2026-11-01T00:00:00Z',
      'ends_at': '2026-11-18T23:59:59Z',
      'priority': 1,
    });
    expect(c.hasDisplayCreative, isTrue);
    expect(c.imageUrlForWidth(390), 'https://example.test/mobile.jpg');
    expect(c.imageUrlForWidth(1440), 'https://example.test/mobile.jpg');
  });

  test(
      'editing, inserting and removing mobile artwork persist the correct pair',
      () {
    final c = PromoCampaignModel.fromJson({
      ...legacy,
      'mobile_image_storage_path': 'mobile.jpg',
      'mobile_image_public_url': 'https://example.test/mobile.jpg'
    });
    for (final payload in [
      c.toInsertJson(createdBy: 'admin'),
      c.toUpdateJson()
    ]) {
      expect(payload['mobile_image_storage_path'], 'mobile.jpg');
      expect(payload['mobile_image_public_url'],
          'https://example.test/mobile.jpg');
      expect(payload['image_public_url'], legacy['image_public_url']);
    }
    final removed = PromoCampaignModel.fromJson(legacy).toUpdateJson();
    expect(removed['mobile_image_public_url'], isNull);
    expect(removed['mobile_image_storage_path'], isNull);
    final blank = PromoCampaignModel.fromJson(
        {...legacy, 'mobile_image_public_url': '  '});
    expect(blank.imageUrlForWidth(390), legacy['image_public_url']);
  });
}
