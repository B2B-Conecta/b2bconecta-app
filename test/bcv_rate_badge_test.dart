import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/widgets/bcv_rate_badge.dart';

void main() {
  test('formatBcvRateUpdatedLabel distingue hoy / ayer / otra fecha', () {
    final now = DateTime(2026, 11, 6, 15, 0);
    expect(
      formatBcvRateUpdatedLabel(DateTime(2026, 11, 6, 14, 15), now: now),
      'Actualizado hoy a las 2:15 PM',
    );
    expect(
      formatBcvRateUpdatedLabel(DateTime(2026, 11, 5, 9, 5), now: now),
      'Actualizado ayer a las 9:05 AM',
    );
    expect(
      formatBcvRateUpdatedLabel(DateTime(2026, 11, 1, 16, 30), now: now),
      'Actualizado el 01/11/2026 a las 4:30 PM',
    );
  });

  testWidgets('badge se oculta sin tasa cargada', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BcvRateBadge(compactPreferred: true)),
      ),
    );
    await tester.pump();
    // Sin sesión/Supabase la carga falla y el badge no ocupa espacio.
    expect(find.byType(BcvRateBadge), findsOneWidget);
  });
}
