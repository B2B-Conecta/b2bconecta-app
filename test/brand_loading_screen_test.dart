import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/widgets/brand_loading_screen.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

void main() {
  testWidgets('the brand pulses without moving the logo or attribution',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandLoadingScreen()));
    final logo = find.byType(B2bConectaMark);
    final attribution = find.text('por B2B Conecta');
    final logoFade =
        find.ancestor(of: logo, matching: find.byType(FadeTransition)).first;
    final initialLogo = tester.getCenter(logo);
    final initialAttribution = tester.getCenter(attribution);
    expect(tester.widget<FadeTransition>(logoFade).opacity.value, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<FadeTransition>(logoFade).opacity.value,
        closeTo(.55, .01));
    expect(tester.getCenter(logo), initialLogo);
    expect(tester.getCenter(attribution), initialAttribution);

    await tester.pump(const Duration(seconds: 1));
    expect(
        tester.widget<FadeTransition>(logoFade).opacity.value, closeTo(1, .01));
  });

  testWidgets('the logo stays fully visible with reduced motion',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const BrandLoadingScreen(),
    ));
    await tester.pumpAndSettle();
    final logoFade = find
        .ancestor(
            of: find.byType(B2bConectaMark),
            matching: find.byType(FadeTransition))
        .first;
    expect(tester.widget<FadeTransition>(logoFade).opacity.value, 1);
  });
}
