import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/aliado_promo_campaign_widgets.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';

PromoCampaignModel campaign(String id) => PromoCampaignModel(
      id: id,
      internalTitle: 'Oferta $id',
      campaignType: PromoCampaignModel.typeBanner,
      imageStoragePath: '$id.jpg',
      imagePublicUrl: 'https://example.test/$id.jpg',
      importadorId: 'supplier-$id',
      actionType: PromoCampaignModel.actionOpenStore,
      startsAt: DateTime(2026, 11, 1),
      endsAt: DateTime(2026, 11, 30),
      priority: 1,
      isActive: true,
    );

void main() {
  Future<void> showBanner(
      WidgetTester tester,
      List<PromoCampaignModel> campaigns,
      ValueChanged<PromoCampaignModel> onTap,
      {bool reduceMotion = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: AliadoPromoBannerCarousel(
                campaigns: campaigns,
                onPromoCampaignSelected: onTap,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('one campaign has no footer or dots and artwork opens its store',
      (tester) async {
    final selected = <String>[];
    await showBanner(tester, [campaign('one')], (c) => selected.add(c.id));
    expect(find.text('Ver promoción'), findsNothing);
    expect(find.bySemanticsLabel('Promoción 1 de 1'), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    expect(selected, ['one']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'dots and swipes select a campaign without opening its destination',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final selected = <String>[];
    await showBanner(
        tester, [campaign('one'), campaign('two')], (c) => selected.add(c.id));
    final secondDot = find.bySemanticsLabel('Promoción 2 de 2');
    expect(secondDot, findsOneWidget);
    await tester.tap(secondDot);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(selected, isEmpty);
    expect(
        tester.getSemantics(secondDot),
        containsSemantics(
            label: 'Promoción 2 de 2',
            isButton: true,
            isSelected: true,
            hasTapAction: true));
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    expect(selected, ['two']);
    final artworkPoint =
        tester.getTopLeft(find.byType(PageView)) + const Offset(120, 24);
    await tester.dragFrom(artworkPoint, const Offset(320, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.getSemantics(find.bySemanticsLabel('Promoción 1 de 2')),
        containsSemantics(isSelected: true));
    await tester.tapAt(artworkPoint);
    expect(selected, ['two', 'one']);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('reduced motion disables autoplay but permits direct pagination',
      (tester) async {
    final selected = <String>[];
    await showBanner(
        tester, [campaign('one'), campaign('two')], (c) => selected.add(c.id),
        reduceMotion: true);
    await tester.pump(const Duration(seconds: 5));
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    expect(selected, ['one']);
    await tester.tap(find.bySemanticsLabel('Promoción 2 de 2'));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    expect(selected, ['one', 'two']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
