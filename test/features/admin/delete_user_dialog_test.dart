import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/delete_user_dialog.dart';
import 'package:motolink_pro_app/features/admin/owner_related_orders.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = ProfileModel(
    id: '11111111-1111-1111-1111-111111111111',
    businessName: 'Taller Norte C.A.',
    email: 'norte@taller.ve',
    role: 'aliado',
  );

  Future<OwnerRelatedOrders> noOrders(String _) async =>
      OwnerRelatedOrders.empty;

  testWidgets('DeleteUserDialog muestra identidad y confirma purga',
      (tester) async {
    String? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showDeleteUserDialog(
                  context: context,
                  profile: profile,
                  loadRelatedOrders: noOrders,
                  onDelete: (confirm) async {
                    confirmed = confirm;
                  },
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

    expect(find.textContaining('¿Eliminar a Taller Norte C.A.?'), findsOneWidget);
    expect(find.text('norte@taller.ve'), findsWidgets);
    expect(
      find.textContaining('eliminará permanentemente'),
      findsOneWidget,
    );
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Eliminar y liberar correo'), findsOneWidget);

    await tester.tap(find.text('Eliminar y liberar correo'));
    await tester.pumpAndSettle();

    expect(confirmed, 'norte@taller.ve');
    expect(find.text('¿Eliminar a Taller Norte C.A.?'), findsNothing);
  });

  testWidgets('DeleteUserDialog se cierra con Escape', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showDeleteUserDialog(
                  context: context,
                  profile: profile,
                  loadRelatedOrders: noOrders,
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
    expect(find.textContaining('¿Eliminar a'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.textContaining('¿Eliminar a'), findsNothing);
  });
}
