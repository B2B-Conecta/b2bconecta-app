import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';

PromoCampaignModel _campaign({
  String actionType = PromoCampaignModel.actionNone,
  String? importadorId,
  String? productId,
  String? externalUrl,
}) {
  final now = DateTime.utc(2026, 10, 1);
  return PromoCampaignModel(
    id: 'c1',
    internalTitle: 'Valla',
    campaignType: PromoCampaignModel.typeBanner,
    imageStoragePath: 'a.jpg',
    imagePublicUrl: 'https://example.com/a.jpg',
    importadorId: importadorId,
    productId: productId,
    actionType: actionType,
    startsAt: now,
    endsAt: now,
    priority: 1,
    isActive: true,
    externalUrl: externalUrl,
  );
}

void main() {
  test('una valla informativa sigue sin destino', () {
    final campaign = _campaign();
    expect(campaign.isTappable, isFalse);
    expect(campaign.opensStore, isFalse);
    expect(campaign.opensProduct, isFalse);
    expect(campaign.toUpdateJson()['product_id'], isNull);
  });

  test('filtrar proveedor no exige producto', () {
    final campaign = _campaign(
      actionType: PromoCampaignModel.actionFilterImporter,
      importadorId: 'imp-1',
    );
    expect(campaign.filtersImporter, isTrue);
    expect(campaign.opensStore, isFalse);
    expect(campaign.isTappable, isTrue);
    expect(campaign.destinationCtaLabel, 'Ver proveedor');
    expect(campaign.toUpdateJson()['product_id'], isNull);
  });

  test('el enlace externo se conserva', () {
    final campaign = _campaign(
      actionType: PromoCampaignModel.actionExternalUrl,
      externalUrl: 'https://example.com',
    );
    expect(campaign.opensExternalUrl, isTrue);
    expect(campaign.isTappable, isTrue);
  });

  test('la vitrina exige proveedor y no producto', () {
    expect(
      _campaign(actionType: PromoCampaignModel.actionOpenStore).opensStore,
      isFalse,
    );
    final campaign = _campaign(
      actionType: PromoCampaignModel.actionOpenStore,
      importadorId: 'imp-1',
      productId: 'prod-1',
    );
    expect(campaign.opensStore, isTrue);
    expect(campaign.opensProduct, isFalse);
    expect(campaign.destinationCtaLabel, 'Ver vitrina');
  });

  test('el producto exige proveedor y producto publicado', () {
    expect(
      _campaign(
        actionType: PromoCampaignModel.actionOpenProduct,
        importadorId: 'imp-1',
      ).opensProduct,
      isFalse,
    );
    final campaign = PromoCampaignModel.fromAliadoRpcJson({
      'id': 'c1',
      'display_title': 'Oferta',
      'campaign_type': 'banner',
      'image_public_url': 'https://example.com/a.jpg',
      'importador_id': 'imp-1',
      'product_id': 'prod-1',
      'action_type': 'open_product',
      'priority': 2,
    });
    expect(campaign.opensProduct, isTrue);
    expect(campaign.productId, 'prod-1');
    expect(campaign.destinationCtaLabel, 'Ver producto');
    expect(campaign.toInsertJson(createdBy: 'admin')['product_id'], 'prod-1');
  });

  test('editar conserva el producto de la fila', () {
    final campaign = PromoCampaignModel.fromJson({
      'id': 'c1',
      'internal_title': 'Valla',
      'campaign_type': 'banner',
      'image_storage_path': 'a.jpg',
      'image_public_url': 'https://example.com/a.jpg',
      'importador_id': 'imp-1',
      'product_id': 'prod-9',
      'action_type': 'open_product',
      'starts_at': '2026-10-01T00:00:00Z',
      'ends_at': '2026-11-01T00:00:00Z',
      'priority': 0,
      'is_active': true,
    });
    expect(campaign.productId, 'prod-9');
    expect(campaign.toUpdateJson()['importador_id'], 'imp-1');
  });
}
