import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/admin_audit_event.dart';
import 'package:motolink_pro_app/features/admin/activity_presence_view.dart';
import 'package:motolink_pro_app/features/admin/owner_account_create_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OwnerAccountCreateRules live field rules', () {
    test('valida RIF y teléfono', () {
      expect(OwnerAccountCreateRules.rifError(''), isNull);
      expect(OwnerAccountCreateRules.rifError('J-12345678-9'), isNull);
      expect(OwnerAccountCreateRules.rifError('abc'), isNotNull);
      expect(OwnerAccountCreateRules.phoneError('04121234567'), isNull);
      expect(OwnerAccountCreateRules.phoneError('12'), isNotNull);
    });

    test('validateDossier incluye RIF inválido', () {
      expect(
        OwnerAccountCreateRules.validateDossier(
          businessName: 'Taller',
          rif: 'malo',
        ),
        isNotNull,
      );
      expect(
        OwnerAccountCreateRules.validateDossier(
          businessName: 'Taller',
          rif: 'J-30012345-6',
        ),
        isNull,
      );
    });
  });

  group('AdminAuditEvent', () {
    test('sampleRows cubre columnas de auditoría', () {
      final rows = AdminAuditEvent.sampleRows();
      expect(rows.length, greaterThanOrEqualTo(5));
      expect(rows.first.ipOrSource, isNotEmpty);
      expect(rows.any((e) => e.action == AdminAuditAction.softDelete), isTrue);
      expect(rows.any((e) => e.action == AdminAuditAction.kycApproved), isTrue);
    });
  });

  testWidgets('Activity log muestra encabezado y columnas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActivityPresenceView(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Log de auditoría'), findsOneWidget);
    expect(find.textContaining('Fecha'), findsWidgets);
    expect(find.text('Presencia'), findsOneWidget);

    await tester.tap(find.text('Presencia'));
    await tester.pumpAndSettle();

    expect(find.text('Presencia'), findsWidgets);
    expect(find.text('Auditoría'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
    expect(find.text('Catálogos publicados'), findsWidgets);
  });
}
