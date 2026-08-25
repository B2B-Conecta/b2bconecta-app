import 'dart:typed_data';

/// Result of a native HTML file input on Flutter Web.
class WebPickedFile {
  const WebPickedFile({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// MIME types that iOS Safari accepts for photos + PDF.
const kWebAcceptImagesAndPdf = 'image/*,application/pdf';

/// Photos only — Safari iOS offers Cámara, Fototeca y Archivos.
const kWebAcceptImagesOnly = 'image/*';

/// Spreadsheet import (Excel + CSV).
const kWebAcceptSpreadsheet =
    '.xlsx,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv';
