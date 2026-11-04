import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/core/widgets/chat_conversation_widgets.dart';
import 'package:motolink_pro_app/features/support/support_ticket_detail_screen.dart';
import 'package:motolink_pro_app/features/support/support_ticket_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var closed = false;
  var failSend = false;
  var replies = 0;
  var closes = 0;
  SupportTicketModel ticket() => SupportTicketModel(
        id: 'ticket',
        createdBy: 'owner',
        authorRole: 'aliado',
        subject: 'Consulta sobre productos y disponibilidad',
        category: 'plataforma',
        status: closed ? 'cerrado' : 'abierto',
        createdAt: DateTime(2026, 11, 4, 10),
      );
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
        dynamic body;
        var status = 200;
        if (request.url.path.endsWith('/token')) {
          body = {
            'access_token': 'fixture-token',
            'refresh_token': 'fixture-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'owner',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-11-04T00:00:00Z',
            },
          };
        } else if (request.url.path
            .endsWith('/reply_support_ticket_as_owner')) {
          if (failSend) {
            status = 503;
            body = {'message': 'temporarily unavailable', 'code': '503'};
          } else {
            replies++;
          }
        } else if (request.url.path.endsWith('/close_support_ticket')) {
          closes++;
          closed = true;
        } else if (request.url.path.endsWith('/support_tickets')) {
          body = {
            'id': 'ticket',
            'created_by': 'owner',
            'author_role': 'aliado',
            'subject': ticket().subject,
            'category': 'plataforma',
            'status': closed ? 'cerrado' : 'abierto',
            'created_at': '2026-11-04T10:00:00Z',
          };
        } else {
          body = [
            {
              'id': 'message',
              'ticket_id': 'ticket',
              'author_id': 'support',
              'author_role': 'administrador',
              'body': 'Estamos revisando tu consulta de productos.',
              'created_at': '2026-11-04T11:00:00Z',
            },
          ];
        }
        return http.Response(jsonEncode(body), status,
            request: request,
            headers: {'content-type': 'application/json'});
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'fixture@example.test',
      password: 'fixture',
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    closed = false;
    failSend = false;
    replies = 0;
    closes = 0;
  });

  Future<void> open(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: SupportTicketDetailScreen(ticket: ticket(), isAdminView: false),
    ));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 1440.0]) {
    testWidgets('support keeps composer at bottom at $width', (tester) async {
      await open(tester, width);
      expect(find.text('Soporte B2B Conecta'), findsNWidgets(2));
      expect(tester.getBottomLeft(find.byType(ChatComposer)).dy, 800);
      expect(find.byType(ChatMessageBubble), findsOneWidget);
      expect(tester.getSize(find.byType(ChatMessageBubble)).width,
          lessThanOrEqualTo(1100));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('support moves composer above keyboard and sends a reply',
      (tester) async {
    await open(tester, 390);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byType(ChatComposer)).dy, 520);
    await tester.enterText(find.byType(TextField), 'Gracias por revisar.');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(replies, 1);
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed reply keeps the draft for retry', (tester) async {
    await open(tester, 390);
    failSend = true;
    await tester.enterText(find.byType(TextField), 'Mi consulta');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Mi consulta');
    expect(find.textContaining('No se pudo enviar el mensaje'), findsOneWidget);
  });

  testWidgets('close requires confirmation and disables replies',
      (tester) async {
    await open(tester, 390);
    await tester.tap(find.byTooltip('Opciones del reclamo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar reclamo'));
    await tester.pumpAndSettle();
    expect(closes, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar reclamo'));
    await tester.pumpAndSettle();
    expect(closes, 1);
    expect(find.byType(ChatComposer), findsNothing);
    expect(find.text('Reclamo cerrado · Solo lectura'), findsOneWidget);
  });
}
