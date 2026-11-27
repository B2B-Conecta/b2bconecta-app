import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/new_consultation_screen.dart';
import 'package:motolink_pro_app/features/catalog/store_supplier_chat.dart';
import 'package:motolink_pro_app/features/catalog/consultation_media.dart';
import 'package:motolink_pro_app/features/orders/shared/order_message_pick.dart';

const suppliers = [
  ImporterOption(
      id: 'supplier', businessName: 'Repuestos Delta', ciudad: 'Caracas'),
  ImporterOption(id: 'other', businessName: 'Moto Oriente', ciudad: 'Barcelona')
];
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var persisted = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.supabase.co',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          dynamic body;
          if (request.url.path.endsWith('/token')) {
            body = {
              'access_token': 'fixture',
              'refresh_token': 'fixture',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'ally',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-11-01T00:00:00Z'
              }
            };
          } else if (request.url.path.endsWith('/store_supplier_messages')) {
            if (request.method == 'POST') {
              persisted = true;
              body = null;
            } else {
              body = persisted ? {'id': 'message'} : null;
            }
          }
          return http.Response(jsonEncode(body), 200,
              request: request, headers: {'content-type': 'application/json'});
        }));
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'qa@example.test', password: 'fixture');
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    requests.clear();
    persisted = false;
  });
  Future<void> pump(WidgetTester tester, NewConsultationScreen screen,
      {double width = 390, double scale = 1}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 844), textScaler: TextScaler.linear(scale)),
            child: screen)));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String text) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final button = find.text(text);
    if (button.evaluate().isEmpty) {
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).first);
    }
    await Scrollable.ensureVisible(tester.element(button), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lS8AAAAASUVORK5CYII=');
  testWidgets(
      'draft and photo survive editing; recipient search and confirmation are explicit',
      (tester) async {
    await pump(
        tester,
        NewConsultationScreen(
            suppliers: suppliers,
            pickPhoto: (_) async => PreparedOrderAttachment(
                bytes: png,
                fileName: 'foto.png',
                mime: 'image/png',
                kind: 'image')));
    await press(tester, 'Elegir proveedor');
    expect(find.text('Escribe qué repuesto necesitas.'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Busco pastillas de freno');
    await tester.enterText(find.byType(TextFormField).at(1), 'Moto 150 cc');
    await tester.ensureVisible(find.text('Agregar foto'));
    await tester.tap(find.text('Agregar foto'));
    await tester.pumpAndSettle();
    await press(tester, 'Elegir proveedor');
    expect(find.text('Busco pastillas de freno'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Caracas');
    await tester.pumpAndSettle();
    expect(find.text('Moto Oriente'), findsNothing);
    await tester.tap(find.text('Repuestos Delta'));
    await tester.pumpAndSettle();
    expect(find.text('Se enviará solo a Repuestos Delta.'), findsOneWidget);
    await tester.ensureVisible(find.text('Editar'));
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Busco pastillas de freno');
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('La consulta no genera un pedido.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed sends keep draft and reuse message ID on retry',
      (tester) async {
    final ids = <String>[];
    await pump(
        tester,
        NewConsultationScreen(
            suppliers: suppliers,
            sendOverride: (s, t, m, p, id) async {
              ids.add(id);
              throw Exception('offline');
            }));
    await tester.enterText(find.byType(TextFormField).first, 'Busco un caucho');
    await press(tester, 'Elegir proveedor');
    await tester.tap(find.text('Repuestos Delta'));
    await tester.pumpAndSettle();
    await press(tester, 'Enviar consulta');
    expect(find.textContaining('Conservamos el texto'), findsOneWidget);
    await press(tester, 'Enviar consulta');
    expect(ids.length, 2);
    expect(ids[0], ids[1]);
    expect(find.text('Busco un caucho'), findsOneWidget);
  });
  testWidgets('back goes to draft and leaving asks before discarding',
      (tester) async {
    await pump(tester, const NewConsultationScreen(suppliers: suppliers));
    await tester.enterText(find.byType(TextFormField).first, 'Repuesto');
    await press(tester, 'Elegir proveedor');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Tu consulta'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar la consulta?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
  for (final size in [(320.0, 1.6), (390.0, 1.0), (1280.0, 1.0)]) {
    testWidgets('both steps fit $size', (tester) async {
      await pump(tester, const NewConsultationScreen(suppliers: suppliers),
          width: size.$1, scale: size.$2);
      await tester.enterText(
          find.byType(TextFormField).first, 'Consulta de prueba');
      await press(tester, 'Elegir proveedor');
      expect(tester.getRect(find.text('Enviar consulta')).bottom,
          lessThanOrEqualTo(844));
      await tester.scrollUntilVisible(find.text('Moto Oriente'), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Moto Oriente'));
      expect(tester.takeException(), isNull);
    });
  }
  test('send persists model once and retries do not insert duplicates',
      () async {
    final id = newConsultationMessageId();
    await StoreSupplierChatService.sendConsultation(
        threadId: 'thread',
        messageId: id,
        body: 'Busco una pieza',
        model: 'Moto 150');
    await StoreSupplierChatService.sendConsultation(
        threadId: 'thread',
        messageId: id,
        body: 'Busco una pieza',
        model: 'Moto 150');
    final writes = requests
        .where((r) =>
            r.method == 'POST' &&
            r.url.path.endsWith('/store_supplier_messages'))
        .toList();
    expect(writes.length, 1);
    expect(jsonDecode(writes.single.body)['consultation_model'], 'Moto 150');
    expect(jsonDecode(writes.single.body)['id'], id);
  });
  test('message parser preserves photo and model while supporting old messages',
      () {
    final message = StoreSupplierMessage.fromJson({
      'id': 'm',
      'body': 'Hola',
      'consultation_model': '150 cc',
      'attachments': [
        {
          'path': 'thread/ally/message/foto.jpg',
          'kind': 'image',
          'mime': 'image/jpeg',
          'name': 'foto.jpg'
        }
      ]
    });
    expect(message.consultationModel, '150 cc');
    expect(message.attachments.length, 1);
    expect(
        StoreSupplierMessage.fromJson({'body': 'viejo'}).attachments, isEmpty);
  });
}
