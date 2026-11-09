import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/aliado_promo_campaign_widgets.dart';
import 'package:motolink_pro_app/features/catalog/promo_banner_layout.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';

void main() {
  test('footer removes repeated generic labels but preserves meaningful names',
      () {
    PromoCampaignModel campaign(String title, {bool advertising = false}) =>
        PromoCampaignModel(
          id: 'caption',
          internalTitle: '',
          displayTitle: title,
          campaignType: 'banner',
          imageStoragePath: '',
          imagePublicUrl: '',
          actionType: 'none',
          startsAt: DateTime(2026),
          endsAt: DateTime(2027),
          priority: 1,
          isActive: true,
          sponsorType: advertising
              ? PromoCampaignModel.sponsorTercero
              : PromoCampaignModel.sponsorImportador,
          advertiserName: advertising ? title : null,
        );
    expect(promoBannerCaption(campaign('Motoboxes - Promocion')), 'Motoboxes');
    expect(promoBannerCaption(campaign('Promoción · Motoboxes - Promoción')),
        'Motoboxes');
    expect(promoBannerCaption(campaign('Repuestos - Caracas')),
        'Repuestos - Caracas');
    expect(promoBannerCaption(campaign('Promociones del Centro')),
        'Promociones del Centro');
    expect(promoBannerCaption(campaign('')), 'Promoción');
    expect(promoBannerCaption(campaign('Marca externa', advertising: true)),
        'Publicidad · Marca externa');
  });

  test('frame uses fixed 3:1 on phones and 7:1 on wide windows', () {
    final phone = promoBannerFrameSize(390);
    expect(phone.width / phone.height, closeTo(PromoBannerSpec.mobileAspect, .001));
    expect(phone.height, lessThanOrEqualTo(180));

    final desktop = promoBannerFrameSize(1400);
    expect(
      desktop.width / desktop.height,
      closeTo(PromoBannerSpec.desktopAspect, .001),
    );
    expect(desktop.height, lessThanOrEqualTo(220));
    expect(desktop.width, lessThanOrEqualTo(1400));
  });

  test('resolution guard rejects undersized crops', () {
    expect(
      promoBannerResolutionError(width: 800, height: 114, mobile: false),
      contains('1200'),
    );
    expect(
      promoBannerResolutionError(width: 2100, height: 300, mobile: false),
      isNull,
    );
    expect(
      promoBannerResolutionError(width: 900, height: 300, mobile: true),
      contains('1200'),
    );
    expect(
      promoBannerResolutionError(width: 1200, height: 400, mobile: true),
      isNull,
    );
  });

  for (final width in [360.0, 1400.0]) {
    testWidgets(
        'artwork stays centered without a footer and opens its destination at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final campaign = PromoCampaignModel(
        id: 'test',
        internalTitle: 'Oferta',
        displayTitle: 'Motoboxes - Promocion',
        campaignType: 'banner',
        imageStoragePath: 'test.png',
        imagePublicUrl: 'https://example.invalid/test.png',
        actionType: PromoCampaignModel.actionFilterImporter,
        importadorId: 'supplier',
        startsAt: DateTime(2026, 11, 1),
        endsAt: DateTime(2026, 11, 18),
        priority: 1,
        isActive: true,
      );
      PromoCampaignModel? opened;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: AliadoPromoBannerCarousel(
        campaigns: [campaign],
        onPromoCampaignSelected: (value) => opened = value,
      ))));
      await tester.pump();
      expect(
          tester.getCenter(find.byType(PageView)).dx, closeTo(width / 2, .5));
      expect(find.text('Motoboxes'), findsNothing);
      expect(find.text('Ver promoción'), findsNothing);
      expect(
          tester.getSize(find.byType(PageView)).height, lessThanOrEqualTo(220));
      final expectedRatio = PromoBannerSpec.aspectForWidth(width);
      final pageSize = tester.getSize(find.byType(PageView));
      expect(pageSize.width / pageSize.height, closeTo(expectedRatio, .05));
      await tester.tap(find.byType(PageView));
      expect(opened, same(campaign));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
