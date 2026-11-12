import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/users_data_table.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewer = ProfileModel(
    id: 'viewer-admin',
    businessName: 'Ops',
    email: 'ops@b2bconecta.ve',
    role: 'administrador',
    isOwner: true,
  );

  test('sampleRows incluye 5 talleres/operadores VE', () {
    final rows = UsersDataTable.sampleRows();
    expect(rows, hasLength(5));
    expect(
      rows.map((e) => e.businessName),
      containsAll(<String>[
        'Taller Moto Ruices',
        'Importadora Valencia Parts',
        'B2B Conecta Ops',
        'Taller El Rayo Caracas',
        'Mayorista Andes Lubricantes',
      ]),
    );
  });

  testWidgets('muestra búsqueda, contador y paginación', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UsersDataTable(
              profiles: [],
              viewer: viewer,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buscar por nombre o correo…'), findsOneWidget);
    expect(find.textContaining('ejemplos'), findsOneWidget);
    expect(find.textContaining('Mostrando'), findsOneWidget);
    expect(find.textContaining('Crear / Invitar Usuario'), findsOneWidget);
    expect(find.text('Taller Moto Ruices'), findsOneWidget);
    expect(find.text('Proveedor'), findsWidgets);
    expect(find.text('Taller comprador'), findsWidgets);
  });

  testWidgets('filtra por nombre en tiempo real', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UsersDataTable(
              profiles: [],
              viewer: viewer,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Rayo');
    await tester.pumpAndSettle();

    expect(find.text('Taller El Rayo Caracas'), findsOneWidget);
    expect(find.text('Taller Moto Ruices'), findsNothing);
    expect(find.textContaining('1 ejemplo'), findsOneWidget);
  });
}
