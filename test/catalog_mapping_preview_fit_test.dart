import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/importer_flexible_import_screen.dart';

void main() {
  test('grows to 7 rows when the mapping card is tall enough', () {
    final fit = catalogMappingPreviewFit(
      mappingHeight: 560,
      previewHeight: 360,
      tableHeight: 220,
      sampleCount: 7,
    );
    expect(fit.rows, 7);
    expect(fit.height, greaterThan(220));
  });

  test('stops at the rows that still fit inside the mapping card', () {
    // chrome = 140. available = 390. (390 - 40 - 14) / 36 = 9.3 → cap 7.
    // A shorter card fits only 6 full rows.
    final fit = catalogMappingPreviewFit(
      mappingHeight: 140 + 40 + 14 + 36 * 6 + 10,
      previewHeight: 360,
      tableHeight: 220,
      sampleCount: 7,
    );
    expect(fit.rows, 6);
  });

  test('stays at 5 rows when one more row would pass the mapping card', () {
    final fit = catalogMappingPreviewFit(
      mappingHeight: 380,
      previewHeight: 360,
      tableHeight: 220,
      sampleCount: 7,
    );
    expect(fit.rows, catalogMappingPreviewInitialRows);
    expect(fit.height, catalogMappingPreviewInitialHeight);
  });

  test('stays at the initial size when the file has only 5 sample rows', () {
    final fit = catalogMappingPreviewFit(
      mappingHeight: 560,
      previewHeight: 360,
      tableHeight: 220,
      sampleCount: 5,
    );
    expect(fit.rows, 5);
    expect(fit.height, 220);
  });
}
