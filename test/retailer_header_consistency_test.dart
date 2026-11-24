import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/aliado_branded_header.dart';
import 'package:motolink_pro_app/core/widgets/aliado_header_search.dart';
import 'package:motolink_pro_app/core/widgets/bcv_rate_badge.dart';
import 'package:motolink_pro_app/core/widgets/ios_chrome.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_branded_header.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = ProfileModel(
      id: 'retailer',
      role: 'aliado',
      businessName: 'Taller de prueba con un nombre largo');
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.supabase.co',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false),
        httpClient: MockClient((request) async => http.Response('[]', 200,
            request: request, headers: {'content-type': 'application/json'})));
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final scenario in [
    (320.0, 1.0, 0.0),
    (390.0, 1.0, 24.0),
    (320.0, 1.6, 24.0)
  ]) {
    testWidgets('retailer toolbar and search align across modules at $scenario',
        (tester) async {
      tester.view.physicalSize = Size(scenario.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final search = TextEditingController();
      addTearDown(search.dispose);
      Future<void> pump(Widget body) async {
        await tester.pumpWidget(MaterialApp(
            theme: buildAppTheme(),
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(scenario.$1, 900),
                    viewPadding: EdgeInsets.only(top: scenario.$3),
                    textScaler: TextScaler.linear(scenario.$2)),
                child: Scaffold(body: body))));
        await tester.pumpAndSettle();
      }

      Widget staticHeader({bool withSearch = false, double progress = 0}) =>
          AliadoBrandedHeader(
              profile: profile,
              onMessagesTap: () {},
              onNotificationTap: () {},
              searchCollapseProgress: progress,
              onSearchTap: withSearch ? () {} : null,
              footer: withSearch
                  ? AliadoHeaderSearch(
                      controller: search,
                      hint: 'Buscar pedido o proveedor…',
                      onSearch: () {},
                      onFilters: () {})
                  : null);
      await pump(CustomScrollView(slivers: [
        AliadoCatalogBrandedHeader(
            profile: profile,
            searchController: search,
            onSearchSubmitted: () {},
            onOpenSearch: () {},
            onOpenFilters: () {},
            onMessagesTap: () {}),
        const SliverToBoxAdapter(child: SizedBox(height: 2000)),
      ]));
      final expanded = tester.getSize(find.byType(IosGlass).first).height;
      final searchRect = tester.getRect(find.byType(TextField));
      final bcv = tester.getRect(find.byType(BcvRateBadge));
      expect(searchRect.left, 14);
      expect(searchRect.right, scenario.$1 - 14);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -170));
      await tester.pumpAndSettle();
      final collapsed = tester.getSize(find.byType(IosGlass).first).height;
      final compactBcv = tester.getRect(find.byType(BcvRateBadge));
      expect(collapsed, lessThan(expanded));
      expect(find.text('Tienda minorista'), findsNothing);
      await pump(Column(children: [
        staticHeader(withSearch: true),
        const Expanded(child: SizedBox())
      ]));
      expect(tester.getSize(find.byType(IosGlass).first).height,
          closeTo(expanded, .1));
      expect(tester.getRect(find.byType(TextField)), searchRect);
      expect(tester.getRect(find.byType(BcvRateBadge)), bcv);
      await pump(Column(children: [
        staticHeader(withSearch: true, progress: 1),
        const Expanded(child: SizedBox())
      ]));
      expect(tester.getSize(find.byType(IosGlass).first).height,
          closeTo(collapsed, .1));
      expect(tester.getRect(find.byType(BcvRateBadge)), compactBcv);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Tienda minorista'), findsNothing);
      for (final tab in ['Favoritos', 'Perfil']) {
        await pump(
            Column(children: [staticHeader(), Expanded(child: Text(tab))]));
        expect(tester.getSize(find.byType(IosGlass).first).height,
            closeTo(collapsed, .1));
        expect(tester.getRect(find.byType(BcvRateBadge)), bcv);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
