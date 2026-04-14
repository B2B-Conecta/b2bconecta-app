import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/screens/login_screen.dart';

void main() {
  testWidgets('Login screen shows welcome text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('MotoLink'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}
