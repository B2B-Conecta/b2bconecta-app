import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/account_action_dialogs.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = ProfileModel(
    id: '11111111-1111-1111-1111-111111111111',
    businessName: 'Taller Norte C.A.',
    email: 'norte@taller.ve',
    role: 'aliado',
  );

  testWidgets('suspender acceso usa copy amigable y chips', (tester) async {
    String? note;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                note = await showSuspendAccessDialog(
                  context: context,
                  profile: profile,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Suspender acceso temporalmente'), findsOneWidget);
    expect(find.text('Taller Norte C.A.'), findsWidgets);
    expect(find.text('Inactividad'), findsOneWidget);

    await tester.tap(find.text('Inactividad'));
    await tester.pump();
    await tester.tap(find.text('Suspender acceso'));
    await tester.pumpAndSettle();

    expect(note, 'Inactividad');
  });

  testWidgets('desactivar cuenta evita tecnicismos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showDeactivateAccountDialog(
                  context: context,
                  profile: profile,
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Desactivar cuenta'), findsWidgets);
    expect(find.textContaining('soft delete'), findsNothing);
    expect(find.textContaining('hard delete'), findsNothing);
    expect(find.text('Desactivar cuenta'), findsWidgets);
  });
}
