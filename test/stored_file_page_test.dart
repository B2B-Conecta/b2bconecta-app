import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/utils/stored_file_name.dart';
import 'package:motolink_pro_app/core/utils/stored_file_page.dart';

void main() {
  test('detects image proofs and keeps pdfs as documents', () {
    expect(storedFileIsImage('comprobante.jpg'), isTrue);
    expect(storedFileIsImage('foto.PNG'), isTrue);
    expect(storedFileIsImage('factura.pdf'), isFalse);
    expect(
      storedFileIsImage(
        'archivo',
        'https://example.com/storage/v1/object/sign/proofs/pago.webp?token=1',
      ),
      isTrue,
    );
  });

  testWidgets('a pdf offers view and download once the link is ready',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoredFilePage(
          loadUrl: () async => 'https://example.com/factura.pdf',
          fileName: 'factura.pdf',
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Ver archivo'), findsOneWidget);
    expect(find.text('Descargar'), findsOneWidget);
    expect(find.text('factura.pdf'), findsOneWidget);
  });
}
