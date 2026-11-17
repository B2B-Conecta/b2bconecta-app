import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;

import '../../core/utils/excel_file_export.dart';
import '../catalog/part_model.dart';

abstract final class InventoryQrLabel {
  static const prefix = 'B2BINV1:';
  static final _id = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String encode(String productId) => '$prefix${productId.toLowerCase()}';

  static String? productId(String value) {
    if (!value.startsWith(prefix)) return null;
    final id = value.substring(prefix.length);
    return id.length == 36 && _id.hasMatch(id) ? id.toLowerCase() : null;
  }

  static String variant(PartModel part) => part.variantAttributes.isNotEmpty
      ? part.variantAttributes.values.join(' · ')
      : part.variantAttributeValue ?? '';

  static Future<Uint8List> buildPdf(List<PartModel> products) {
    final document = pdf.Document(title: 'Etiquetas QR de inventario');
    const perPage = 15;
    for (var start = 0; start < products.length; start += perPage) {
      final page = products.skip(start).take(perPage).toList();
      document.addPage(pdf.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pdf.EdgeInsets.all(24),
        build: (_) => pdf.Column(
          crossAxisAlignment: pdf.CrossAxisAlignment.stretch,
          children: [
            pdf.Text('Etiquetas QR · B2B Conecta',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.SizedBox(height: 12),
            for (var i = 0; i < page.length; i += 3)
              pdf.Row(children: [
                for (var column = 0; column < 3; column++)
                  pdf.Expanded(
                    child: i + column < page.length
                        ? _card(page[i + column])
                        : pdf.SizedBox(),
                  ),
              ]),
          ],
        ),
      ));
    }
    return document.save();
  }

  static pdf.Widget _card(PartModel part) => pdf.Container(
        height: 145,
        alignment: pdf.Alignment.center,
        margin: const pdf.EdgeInsets.all(3),
        padding: const pdf.EdgeInsets.all(8),
        decoration: pdf.BoxDecoration(border: pdf.Border.all(width: 0.5)),
        child: pdf.Column(
          mainAxisAlignment: pdf.MainAxisAlignment.center,
          children: [
            pdf.BarcodeWidget(
              barcode: pdf.Barcode.qrCode(),
              data: encode(part.id),
              width: 76,
              height: 76,
              drawText: false,
            ),
            pdf.SizedBox(height: 6),
            pdf.Text(part.sku ?? 'Sin SKU',
                maxLines: 1,
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text(
                [part.nombre, if (variant(part).isNotEmpty) variant(part)]
                    .join(' · '),
                maxLines: 2,
                textAlign: pdf.TextAlign.center,
                style: const pdf.TextStyle(fontSize: 9)),
          ],
        ),
      );

  static Future<void> download(List<PartModel> products) async {
    if (products.isEmpty) return;
    await saveBytesForExport(
      name: 'etiquetas-qr-inventario',
      bytes: await buildPdf(products),
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
