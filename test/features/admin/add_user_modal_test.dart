import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/add_user_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AddUserModal muestra campos y valida en vivo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddUserModal(allowAdminRole: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Crear / Invitar usuario'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Crear usuario / Enviar invitación'), findsOneWidget);
    expect(find.text('Nombre completo / Razón social'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);

    await tester.tap(find.text('Crear usuario / Enviar invitación'));
    await tester.pumpAndSettle();

    expect(find.text('Indique el nombre comercial.'), findsOneWidget);
    expect(find.text('Indique un correo válido.'), findsOneWidget);
  });

  testWidgets('Minorista muestra datos fiscales y no departamento',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddUserModal(allowAdminRole: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Datos fiscales'), findsOneWidget);
    expect(find.text('RIF / Cédula fiscal'), findsOneWidget);
    expect(find.text('Teléfono / WhatsApp'), findsOneWidget);
    expect(find.text('Departamento'), findsNothing);
    expect(find.text('Tipo de usuario / Rol'), findsOneWidget);
  });

  testWidgets('Escape cierra el modal vía diálogo', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await AddUserModal.open(context, allowAdminRole: false);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Crear / Invitar usuario'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Crear / Invitar usuario'), findsNothing);
    expect(result, anyOf(isNull, isFalse));
  });
}
