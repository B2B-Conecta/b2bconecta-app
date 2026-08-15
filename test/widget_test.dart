import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/core/auth/login_screen.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

void main() {
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
}
