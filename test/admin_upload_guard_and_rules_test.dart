import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/core/utils/upload_file_guard.dart';
import 'package:motolink_pro_app/features/admin/admin_action_rules.dart';

Uint8List _bytes(List<int> head, [int pad = 16]) =>
    Uint8List.fromList([...head, ...List.filled(pad, 0)]);

void main() {
  final jpeg = _bytes([0xFF, 0xD8, 0xFF, 0xE0]);
  final png = _bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final webp = _bytes([
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, //
  ]);
  final pdf = _bytes('%PDF-1.7'.codeUnits);
  final exe = _bytes([0x4D, 0x5A, 0x90, 0x00]);

  group('UploadFileGuard.sniffMime', () {
    test('reconoce JPEG, PNG, WEBP y PDF', () {
      expect(UploadFileGuard.sniffMime(jpeg), 'image/jpeg');
      expect(UploadFileGuard.sniffMime(png), 'image/png');
      expect(UploadFileGuard.sniffMime(webp), 'image/webp');
      expect(UploadFileGuard.sniffMime(pdf), 'application/pdf');
    });

    test('rechaza otras firmas', () {
      expect(UploadFileGuard.sniffMime(exe), isNull);
      expect(UploadFileGuard.sniffMime(Uint8List(0)), isNull);
    });
  });

  group('UploadFileGuard.check', () {
    test('ejecutable renombrado a .pdf no pasa', () {
      expect(
        () => UploadFileGuard.check(exe, 'cedula.pdf',
            kind: UploadKind.imageOrPdf),
        throwsA(isA<UploadRejectedException>()),
      );
    });

    test('PDF no pasa como imagen', () {
      expect(
        () => UploadFileGuard.check(pdf, 'foto.jpg', kind: UploadKind.image),
        throwsA(isA<UploadRejectedException>()),
      );
    });

    test('corrige la extensión al contenido real', () {
      final checked =
          UploadFileGuard.check(png, 'logo.jpg', kind: UploadKind.image);
      expect(checked.mime, 'image/png');
      expect(checked.fileName, 'logo.png');
      expect(checked.extension, 'png');
    });

    test('conserva .jpeg para JPEG', () {
      final checked =
          UploadFileGuard.check(jpeg, 'foto.jpeg', kind: UploadKind.image);
      expect(checked.fileName, 'foto.jpeg');
    });

    test('respeta el tamaño máximo', () {
      final big = Uint8List(UploadFileGuard.maxBytes + 1)
        ..setAll(0, [0xFF, 0xD8, 0xFF]);
      expect(
        () => UploadFileGuard.check(big, 'x.jpg', kind: UploadKind.image),
        throwsA(isA<UploadRejectedException>()),
      );
    });
  });

  group('AdminActionRules', () {
    test('solo administrador ve acciones sensibles', () {
      for (final role in ['administrador', ' Administrador ']) {
        expect(AdminActionRules.canReviewKyc(viewerRole: role), isTrue);
        expect(AdminActionRules.canSetAccountAccess(viewerRole: role), isTrue);
        expect(
          AdminActionRules.canEditCommissionRates(viewerRole: role),
          isTrue,
        );
        expect(
          AdminActionRules.canEditPlatformConfig(viewerRole: role),
          isTrue,
        );
      }
      for (final role in [null, '', 'aliado', 'importador']) {
        expect(AdminActionRules.canReviewKyc(viewerRole: role), isFalse);
        expect(AdminActionRules.canSetAccountAccess(viewerRole: role), isFalse);
        expect(
          AdminActionRules.canEditCommissionRates(viewerRole: role),
          isFalse,
        );
        expect(
          AdminActionRules.canEditPlatformConfig(viewerRole: role),
          isFalse,
        );
      }
    });
  });
}
