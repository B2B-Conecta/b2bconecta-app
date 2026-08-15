import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Resultado al guardar un .xlsx generado en la app.
enum ExcelExportResult {
  saved,
  cancelled,
}

/// Guarda bytes Excel: en iOS/macOS abre «Guardar en Archivos»; en Android/web
/// usa descarga directa (p. ej. carpeta Descargas).
Future<ExcelExportResult> saveExcelForExport({
  required String name,
  required Uint8List bytes,
}) async {
  const ext = 'xlsx';
  const mimeType = MimeType.microsoftExcel;

  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
    final path = await FileSaver.instance.saveAs(
      name: name,
      bytes: bytes,
      ext: ext,
      mimeType: mimeType,
    );
    if (path == null || path.isEmpty) {
      return ExcelExportResult.cancelled;
    }
    return ExcelExportResult.saved;
  }

  await FileSaver.instance.saveFile(
    name: name,
    bytes: bytes,
    ext: ext,
    mimeType: mimeType,
  );
  return ExcelExportResult.saved;
}

/// Mensaje breve según plataforma tras guardar con éxito.
String excelExportSavedMessage(String detail) {
  if (!kIsWeb && Platform.isIOS) {
    return 'Excel guardado en Archivos. $detail';
  }
  return detail;
}
