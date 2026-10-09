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

  test('el dueño solo reemplaza documentos pendientes o rechazados', () {
    expect(DocumentReviewStatus.ownerCanReplace(null), isTrue);
    expect(
      DocumentReviewStatus.ownerCanReplace(DocumentReviewStatus.pendiente),
      isTrue,
    );
    expect(
      DocumentReviewStatus.ownerCanReplace(DocumentReviewStatus.rechazado),
      isTrue,
    );
    expect(
      DocumentReviewStatus.ownerCanReplace(DocumentReviewStatus.enRevision),
      isFalse,
    );
    expect(
      DocumentReviewStatus.ownerCanReplace(DocumentReviewStatus.aprobado),
      isFalse,
    );
  });

  testWidgets('un documento aprobado se puede ver y no reemplazar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileKycDocumentTile(
            title: 'Foto de la tienda',
            hasFile: true,
            statusLabel: 'Aprobado',
            effectiveStatus: DocumentReviewStatus.aprobado,
            reviewNote: 'No debe mostrarse en aprobado',
            showPickActions: false,
            onView: () {},
            onPickCamera: () {},
            onPickGallery: () {},
            onPickFile: () {},
          ),
        ),
      ),
    );

    expect(find.text('Ver archivo'), findsOneWidget);
    expect(find.text('Cámara'), findsNothing);
    expect(find.text('Galería'), findsNothing);
    expect(find.text('Archivo'), findsNothing);
  });

  testWidgets('un documento rechazado muestra el motivo y permite reenviarlo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileKycDocumentTile(
            title: 'Registro mercantil / cámara',
            hasFile: true,
            statusLabel: DocumentReviewStatus.labelEs(
              DocumentReviewStatus.rechazado,
            ),
            effectiveStatus: DocumentReviewStatus.rechazado,
            reviewNote: 'La imagen está cortada.',
            onPickCamera: () {},
            onPickGallery: () {},
            onPickFile: () {},
          ),
        ),
      ),
    );

    expect(find.text('La imagen está cortada.'), findsOneWidget);
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
    expect(find.text('Archivo'), findsOneWidget);
  });
}

void _noop() {}
