import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/catalog/guest_shared_catalog.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/catalog/product_share_destination.dart';
import 'package:motolink_pro_app/features/catalog/product_share_link.dart';
import 'package:motolink_pro_app/features/inventory/importer_product_edit_screen.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = '11111111-2222-3333-4444-555555555555';
  var owner = 'supplier';
  var active = true;
  var visible = true;
  final requests = <http.Request>[];
  Map<String, dynamic> product() => {
        'id': id,
        'owner_id': owner,
        'sku': '0007',
        'name': 'Repuesto de prueba',
        'description': 'Descripción del repuesto',
        'price_usd': 12,
        'stock': 10,
        'is_active': active,
        'image_urls': <String>[],
      };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.supabase.co',
      anonKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        dynamic body;
        if (request.url.path.endsWith('/token')) {
          body = {
            'access_token': 'fixture-token',
            'refresh_token': 'fixture-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'supplier',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-11-03T00:00:00Z',
            },
          };
        } else if (request.url.path.endsWith('/products')) {
          final query = request.url.queryParameters;
          if (query['id'] == 'eq.$id') {
            final matchesOwner =
                query['owner_id'] == null || query['owner_id'] == 'eq.$owner';
            body = visible && matchesOwner ? product() : null;
          } else {
            body = [];
          }
        } else if (request.url.path.endsWith('/public_shared_product')) {
          body = visible && active ? product() : null;
        } else if (request.url.path.endsWith('/profiles')) {
          body = {'id': 'supplier', 'role': 'aliado'};
        } else {
          body = [];
        }
        return http.Response(jsonEncode(body), 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'supplier@example.test',
      password: 'fixture',
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    owner = 'supplier';
    active = true;
    visible = true;
    requests.clear();
    ProductShareLink.pending.value = null;
  });

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('el propietario abre gestión incluso si está pausado',
      (tester) async {
    active = false;
    await open(
        tester,
        const ProductShareDestinationScreen(
          productId: id,
          viewer: ProfileModel(id: 'supplier', role: 'importador'),
        ));
    expect(find.byType(ImporterProductEditScreen), findsOneWidget);
    final query = requests.firstWhere((r) => r.url.path.endsWith('/products'));
    expect(query.url.queryParameters['owner_id'], 'eq.supplier');
    expect(query.url.queryParameters['id'], 'eq.$id');
    expect(tester.takeException(), isNull);
  });

  testWidgets('el cliente abre la ficha sin acceso al editor', (tester) async {
    await open(
        tester,
        const ProductShareDestinationScreen(
          productId: id,
          viewer: ProfileModel(id: 'supplier', role: 'aliado'),
        ));
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.byType(ImporterProductEditScreen), findsNothing);
    expect(
        requests.where((r) =>
            r.url.queryParameters['owner_id'] != null &&
            r.url.queryParameters['id'] == 'eq.$id'),
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('otro mayorista no puede editar el producto', (tester) async {
    owner = 'other-supplier';
    await open(
        tester,
        const ProductShareDestinationScreen(
          productId: id,
          viewer: ProfileModel(id: 'supplier', role: 'importador'),
        ));
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.byType(ImporterProductEditScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un producto inaccesible no abre ficha ni gestión',
      (tester) async {
    visible = false;
    await open(
        tester,
        const ProductShareDestinationScreen(
          productId: id,
          viewer: ProfileModel(id: 'supplier', role: 'aliado'),
        ));
    expect(find.textContaining('Este producto no está disponible.'),
        findsOneWidget);
    expect(find.byType(ProductDetailScreen), findsNothing);
    expect(find.byType(ImporterProductEditScreen), findsNothing);
  });

  for (final register in [true, false]) {
    testWidgets(
        'la vista previa conserva la ficha al ${register ? 'registrarse' : 'entrar'}',
        (tester) async {
      var called = false;
      await open(
          tester,
          GuestSharedProductScreen(
            productId: id,
            onRegister: () {
              if (register) called = true;
            },
            onLogin: () {
              if (!register) called = true;
            },
          ));
      expect(
          tester
              .widget<ProductDetailScreen>(find.byType(ProductDetailScreen))
              .guestPreview,
          isTrue);
      expect(find.text('Regístrate para comprar'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      await tester.tap(
          find.text(register ? 'Regístrate para comprar' : 'Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(await ProductShareLink.take(), id);
      expect(find.byType(ImporterProductEditScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('la vista pública no muestra productos pausados', (tester) async {
    active = false;
    await open(
        tester, GuestSharedProductScreen(productId: id, onRegister: () {}));
    expect(find.text('Este producto no está disponible.'), findsOneWidget);
    expect(find.byType(ProductDetailScreen), findsNothing);
  });
}
