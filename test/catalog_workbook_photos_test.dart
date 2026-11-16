import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_mapping.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_photos.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_validator.dart';
import 'package:motolink_pro_app/features/inventory/catalog_photo_adjustments.dart';
import 'package:motolink_pro_app/features/inventory/catalog_workbook_photos.dart';
import 'package:motolink_pro_app/features/inventory/flexible_catalog_import_service.dart';

void main() {
  test('recupera los dibujos de la hoja correcta y conserva las filas físicas',
      () {
    final source = _workbookWithPhotos();
    final result = readWorkbookPhotos((bytes: source, sheetName: 'Sheet1'));
    expect(result.sheet, 'Sheet1');
    expect(result.photos.map((photo) => photo.sourceRow), [2, 4, 4, null]);
    expect(result.photos.map((photo) => photo.singleRow),
        [true, true, false, false]);
    expect(identical(result.photos[0].bytes, result.photos[1].bytes), isTrue);
    expect(result.issues.single, contains('imagen externa'));
    expect(
      readWorkbookPhotos((bytes: source, sheetName: 'Otra')).photos,
      isEmpty,
    );

    final preview = FlexibleCatalogImportService.previewFile(
      bytes: source,
      meta: const CatalogImportFileMeta(name: 'archivo.xlsm'),
    );
    expect(preview.sampleRows.map((row) => row['sku']), ['MOTO', 'MOTO_2']);
  });

  test('usa la fila exacta y detecta un SKU movido después de revisar', () {
    const row = CatalogImportNormalizedRow(
      rowIndex: 4,
      sku: 'MOTO_2',
      name: 'Disco',
      priceUsd: 10,
      stock: 0,
    );
    final scanned =
        readWorkbookPhotos((bytes: _workbookWithPhotos(), sheetName: null));
    final drafts = CatalogPhotoDraft.fromWorkbook(scanned.photos, {
      'moto_2': (row: row, available: true),
    });
    expect(drafts.map((draft) => draft.sku), ['', 'MOTO_2', '', '']);
    expect(drafts.map((draft) => draft.approved), [false, true, false, false]);
    expect(
        CatalogPhotoDraft.assignmentErrors(drafts, {
          'moto_2': (row: row, available: true),
        }),
        isEmpty);
    const reassigned = CatalogImportNormalizedRow(
      rowIndex: 2,
      sku: 'MOTO_2',
      name: 'Bujía',
      priceUsd: 6,
      stock: 1,
    );
    expect(
        CatalogPhotoDraft.assignmentErrors(drafts, {
          'moto_2': (row: reassigned, available: true),
        }),
        contains('moto_2'));
  });

  test('el recorte elimina un fondo opaco, centra la pieza y permite sombra',
      () {
    final source = img.Image(width: 320, height: 320);
    img.fill(source, color: img.ColorRgb8(170, 120, 85));
    img.fillRect(source,
        x1: 40, x2: 119, y1: 60, y2: 99, color: img.ColorRgb8(38, 43, 49));
    final bytes = img.encodePng(source);
    final mask = Uint8List(catalogMaskSide * catalogMaskSide);
    for (var y = 60; y < 100; y++) {
      mask.fillRange(y * catalogMaskSide + 40, y * catalogMaskSide + 120, 255);
    }
    img.Image render(double fill, {bool shadow = false}) {
      final result = renderCatalogPhotoWithMask((
        request: (
          bytes: bytes,
          preview: false,
          lossless: true,
          adjustments: CatalogPhotoAdjustments(
            whiteBackground: true,
            center: true,
            fill: fill,
            shadow: shadow,
          ),
        ),
        mask: mask,
      ));
      return img.decodePng(result.bytes)!;
    }

    final plain = render(.8);
    final shadow = render(.8, shadow: true);
    expect(plain.width, 100);
    expect(plain.height, 100);
    expect(plain.getPixel(0, 0).r, 255);
    expect(plain.getPixel(50, 50).r, 38);
    expect(shadow.getPixel(50, 71).r, lessThan(plain.getPixel(50, 71).r));
    expect(render(.6).width, 134);
    expect(img.decodePng(bytes)!.getPixel(0, 0).r, 170);
  });

  test('gira, centra y rellena transparencias conservando el original', () {
    final original = _photo();
    final rotated = renderCatalogPhoto((
      bytes: original,
      adjustments: const CatalogPhotoAdjustments(turns: 1),
      preview: false,
      lossless: false,
    ));
    final rotatedImage = img.decodePng(rotated.bytes)!;
    expect(rotatedImage.width, 8);
    expect(rotatedImage.height, 16);
    final edited = renderCatalogPhoto((
      bytes: original,
      adjustments: const CatalogPhotoAdjustments(
        turns: 1,
        center: true,
        whiteBackground: true,
        brightness: 1.1,
      ),
      preview: false,
      lossless: false,
    ));
    expect(edited.extension, 'jpeg');
    final square = img.decodeJpg(edited.bytes)!;
    expect(square.width, 16);
    expect(square.height, 16);
    expect(square.getPixel(0, 0).r, greaterThan(240));
    expect(square.getPixel(8, 8).r, lessThan(150));
    final decodedOriginal = img.decodePng(original)!;
    expect(decodedOriginal.width, 16);
    expect(decodedOriginal.height, 8);
    expect(decodedOriginal.getPixel(0, 0).a, 0);
  });
}

Uint8List _photo() {
  final source = img.Image(width: 16, height: 8, numChannels: 4);
  img.fillRect(source,
      x1: 4, y1: 2, x2: 11, y2: 5, color: img.ColorRgba8(55, 36, 31, 255));
  return img.encodePng(source);
}

Uint8List _workbookWithPhotos() {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([
    'sku',
    'nombre',
    'precio',
    'stock',
  ].map(TextCellValue.new).toList());
  sheet.appendRow([
    TextCellValue('MOTO'),
    TextCellValue('Bujía'),
    IntCellValue(6),
    IntCellValue(2)
  ]);
  sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('MOTO_2');
  sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue('Disco');
  sheet.cell(CellIndex.indexByString('C4')).value = IntCellValue(10);
  sheet.cell(CellIndex.indexByString('D4')).value = IntCellValue(0);
  excel['Otra'].appendRow([TextCellValue('sku')]);

  final archive = ZipDecoder().decodeBytes(excel.encode()!);
  void add(String path, String xml) {
    final bytes = utf8.encode(xml);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  const relNs =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  final part = archive.findFile('xl/worksheets/sheet1.xml')!;
  final sheetXml = utf8.decode(part.content as List<int>);
  add(
      part.name,
      sheetXml.replaceFirst('</worksheet>',
          '<drawing xmlns:r="$relNs" r:id="draw"/></worksheet>'));
  add('xl/worksheets/_rels/sheet1.xml.rels',
      '<Relationships><Relationship Id="draw" Target="../drawings/drawing1.xml"/></Relationships>');
  const picture = '<pic><blip r:embed="image"/></pic>';
  add('xl/drawings/drawing1.xml', '''
<wsDr xmlns:r="$relNs">
  <oneCellAnchor><from><row>1</row></from>$picture</oneCellAnchor>
  <twoCellAnchor><from><row>3</row></from><to><row>4</row><rowOff>0</rowOff></to>$picture</twoCellAnchor>
  <twoCellAnchor><from><row>3</row></from><to><row>4</row><rowOff>1</rowOff></to>$picture</twoCellAnchor>
  <absoluteAnchor>$picture</absoluteAnchor>
  <absoluteAnchor><pic><blip r:embed="external"/></pic></absoluteAnchor>
</wsDr>''');
  add('xl/drawings/_rels/drawing1.xml.rels', '''
<Relationships>
  <Relationship Id="image" Target="/xl/media/disco.png"/>
  <Relationship Id="external" Target="https://example.invalid/foo.jpg" TargetMode="External"/>
</Relationships>''');
  final bytes = _photo();
  archive.addFile(ArchiveFile('xl/media/disco.png', bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
