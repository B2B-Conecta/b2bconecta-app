import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/kyc/document_review_status.dart';
import 'package:motolink_pro_app/features/kyc/profile_kyc_document_tile.dart';

void main() {
  testWidgets('un documento cargado se puede abrir', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileKycDocumentTile(
            title: 'RIF',
            hasFile: true,
            statusLabel: 'Aprobado',
            effectiveStatus: DocumentReviewStatus.aprobado,
            onView: () => opened++,
            onPickCamera: () {},
            onPickGallery: () {},
            onPickFile: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ver archivo'), findsOneWidget);
    await tester.tap(find.text('Ver archivo'));
    expect(opened, 1);
  });

  testWidgets('sin archivo no aparece ver', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileKycDocumentTile(
            title: 'RIF',
            hasFile: false,
            statusLabel: 'Sin archivo',
            effectiveStatus: null,
            onPickCamera: _noop,
            onPickGallery: _noop,
            onPickFile: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Ver archivo'), findsNothing);
  });
}

void _noop() {}
