import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/core/auth/login_screen.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

void main() {
  setUp(() => dotenv.testLoad(fileInput: ''));

  testWidgets('Login screen shows brand logo and sign-in action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.byType(MotoLinkProLogo), findsWidgets);
    expect(find.text('Ingrese a su cuenta'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 800.0, 839.0, 840.0, 1280.0]) {
    for (final register in [false, true]) {
      testWidgets(
        '${register ? 'Registration' : 'Login'} fits a $width px viewport',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 390 ? 1.3 : 1),
                ),
                child: child!,
              ),
              home: LoginScreen(startInRegister: register),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Continuar con Google'), findsOneWidget);
          expect(
            find.text(register ? 'Crear cuenta' : 'Iniciar sesión'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
