import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import 'catalog_import/catalog_import_field.dart';
import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'catalog_import_validator.dart';

/// Lee archivos Excel/CSV arbitrarios y aplica mapeo dinámico fila a fila.
///
/// Diseñado para lotes grandes (9k+ filas): procesa en chunks configurables
/// sin materializar todo el payload RPC en memoria.
class FlexibleCatalogImportService {
  FlexibleCatalogImportService._();

  static const defaultSampleRowCount = 5;

  /// Paso 1: extrae cabeceras y filas de muestra para el wizard de mapeo.
  static CatalogImportPreview previewFile({
    required Uint8List bytes,
    required CatalogImportFileMeta meta,
  }) {
    final table = _readTabular(bytes, meta);
    if (table.headers.isEmpty) {
      throw const FormatException('No se detectaron cabeceras.');
    }

    final headerIdx = meta.headerRow - 1;
    if (headerIdx < 0 || headerIdx >= table.rows.length) {
      throw FormatException(
        'header_row=${meta.headerRow} fuera de rango (${table.rows.length} filas).',
      );
    }

    final headers = table.headers;
    final dataStart = meta.dataStartsAtRow - 1;
    final samples = <Map<String, String>>[];
    var dataRows = 0;

    for (var r = dataStart; r < table.rows.length; r++) {
      final raw = table.rows[r];
      if (_rowIsEmpty(raw)) continue;
      dataRows++;
      if (samples.length < defaultSampleRowCount) {
        samples.add(_zipRow(headers, raw));
      }
    }

    return CatalogImportPreview(
      headers: headers,
      sampleRows: samples,
      totalDataRowsEstimate: dataRows,
    );
  }

  /// Paso 2: parsea + valida el archivo completo en lotes.
  static Stream<CatalogImportParseBatch> parseInBatches({
    required Uint8List bytes,
    required CatalogImportMapping mapping,
  }) {
    final missing = mapping.missingRequiredFields();
    if (missing.isNotEmpty) {
      throw FormatException(
        'Faltan campos obligatorios en column_map: ${missing.join(', ')}',
      );
    }

    final batchSize = mapping.options.batchSize.clamp(50, 1000);
    final table = _readTabular(bytes, mapping.file);
    final headers = table.headers;
    final dataStart = mapping.file.dataStartsAtRow - 1;

    Stream<CatalogImportParseBatch> stream() async* {
      final buffer = <CatalogImportNormalizedRow>[];

      for (var r = dataStart; r < table.rows.length; r++) {
        final rawCells = table.rows[r];
        if (_rowIsEmpty(rawCells)) continue;

        final rawByHeader = _zipRow(headers, rawCells);
        try {
          final mapped = CatalogImportValidator.mapRawRow(
            rowIndex: r + 1,
            rawByHeader: rawByHeader,
            mapping: mapping,
          );
          if (mapped != null) buffer.add(mapped);
        } on FormatException catch (e) {
          yield CatalogImportParseBatch(
            validRows: const [],
            errors: [
              CatalogImportRowError(
                rowIndex: r + 1,
                code: 'PARSE_ERROR',
                message: _parseErrorMessage(e.message),
              ),
            ],
          );
          continue;
        }

        if (buffer.length >= batchSize) {
          yield CatalogImportValidator.validateBatch(buffer);
          buffer.clear();
        }
      }

      if (buffer.isNotEmpty) {
        yield CatalogImportValidator.validateBatch(buffer);
      }
    }

    return stream();
  }

  /// Compatibilidad con plantilla fija existente → mapping automático.
  static CatalogImportMapping legacyTemplateMapping({
    String fileName = 'plantilla.xlsx',
  }) {
    CatalogImportColumnBinding bind(String source) =>
        CatalogImportColumnBinding(source: source, required: true);

    return CatalogImportMapping(
      file: CatalogImportFileMeta(name: fileName),
      options: const CatalogImportOptions(),
      columnMap: {
        CatalogImportField.sku.key: bind('sku'),
        CatalogImportField.name.key: bind('nombre'),
        CatalogImportField.description.key: CatalogImportColumnBinding(
          source: 'descripcion (opcional)',
        ),
        CatalogImportField.priceUsd.key: bind('precio'),
        CatalogImportField.salePriceUsd.key: CatalogImportColumnBinding(
          source: 'precio_oferta_usd (opcional)',
        ),
        CatalogImportField.stock.key: bind('stock'),
        CatalogImportField.minOrderQty.key: CatalogImportColumnBinding(
          source: 'cantidad_minima',
        ),
        CatalogImportField.category.key: CatalogImportColumnBinding(
          source: 'categoria (opcional)',
        ),
        CatalogImportField.compatibility.key: CatalogImportColumnBinding(
          source: 'compatibilidad (opcional)',
        ),
        CatalogImportField.hasWarranty.key: CatalogImportColumnBinding(
          source: 'garantia (opcional)',
          transform: CatalogImportTransform.booleanSiNo,
        ),
        CatalogImportField.usdPaymentDiscountPct.key: CatalogImportColumnBinding(
          source: 'descuento_pago_usd_pct (opcional)',
          transform: CatalogImportTransform.decimalComma,
        ),
      },
    );
  }

  static _TabularData _readTabular(Uint8List bytes, CatalogImportFileMeta meta) {
    if (meta.format == CatalogImportFileFormat.csv) {
      return _readCsv(bytes, meta);
    }
    return _readXlsx(bytes, meta);
  }

  static _TabularData _readXlsx(Uint8List bytes, CatalogImportFileMeta meta) {
    late final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      if (e.toString().contains('custom numFmtId starts at 164')) {
        excel = Excel.decodeBytes(_sanitizeInvalidNumFmtIds(bytes));
      } else {
        rethrow;
      }
    }

    if (excel.tables.isEmpty) {
      throw const FormatException('El archivo no contiene hojas.');
    }

    final sheet = meta.sheetName != null
        ? excel.tables[meta.sheetName]
        : excel.tables.values.first;
    if (sheet == null) {
      throw FormatException('Hoja no encontrada: ${meta.sheetName}');
    }

    final headerIdx = meta.headerRow - 1;
    if (headerIdx < 0 || headerIdx >= sheet.maxRows) {
      throw FormatException('Fila de cabecera inválida: ${meta.headerRow}');
    }

    final headerRow = sheet.rows[headerIdx];
    final headers = <String>[];
    for (var c = 0; c < headerRow.length; c++) {
      final raw = _cellText(headerRow[c]).trim();
      headers.add(raw.isEmpty ? 'column_$c' : raw);
    }

    final rows = <List<String>>[];
    for (var r = 0; r < sheet.maxRows; r++) {
      final src = sheet.rows[r];
      final out = List<String>.filled(headers.length, '');
      for (var c = 0; c < headers.length; c++) {
        out[c] = _cellText(_col(src, c));
      }
      rows.add(out);
    }

    return _TabularData(headers: headers, rows: rows);
  }

  static _TabularData _readCsv(Uint8List bytes, CatalogImportFileMeta meta) {
    final text = _decodeText(bytes, meta.encoding);
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty) {
      return const _TabularData(headers: [], rows: []);
    }

    final delimiter = detectCsvDelimiter(
      text,
      fallback: meta.csvDelimiter,
    );
    final parsed = lines.map((l) => _parseCsvLine(l, delimiter)).toList();

    final headerIdx = meta.headerRow - 1;
    if (headerIdx < 0 || headerIdx >= parsed.length) {
      throw FormatException('Fila de cabecera inválida: ${meta.headerRow}');
    }

    final headers = parsed[headerIdx]
        .map((h) {
          var t = h.trim();
          if (t.startsWith('\uFEFF')) t = t.substring(1).trim();
          return t.isEmpty ? 'column' : t;
        })
        .toList();

    return _TabularData(headers: headers, rows: parsed);
  }

  static String _decodeText(Uint8List bytes, String encoding) {
    final enc = encoding.toLowerCase();
    if (enc == 'latin1' || enc == 'iso-8859-1' || enc == 'windows-1252') {
      return latin1.decode(bytes, allowInvalid: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static Map<String, String> _zipRow(List<String> headers, List<String> row) {
    final out = <String, String>{};
    for (var i = 0; i < headers.length; i++) {
      final key = headers[i];
      if (key.isEmpty) continue;
      out[key] = i < row.length ? row[i] : '';
    }
    return out;
  }

  static bool _rowIsEmpty(List<String> row) {
    for (final c in row) {
      if (c.trim().isNotEmpty) return false;
    }
    return true;
  }

  static Data? _col(List<Data?> row, int i) {
    if (i < 0 || i >= row.length) return null;
    return row[i];
  }

  static String _cellText(Data? cell) {
    if (cell == null) return '';
    final v = cell.value;
    if (v == null) return '';
    return v.toString();
  }

  /// Elige `,` `;` o tabulador según la primera línea con datos.
  static String detectCsvDelimiter(String text, {String fallback = ','}) {
    final lines = const LineSplitter().convert(text);
    String sample = '';
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      sample = t.startsWith('\uFEFF') ? t.substring(1) : t;
      break;
    }
    if (sample.isEmpty) return fallback.isEmpty ? ',' : fallback;

    final counts = <String, int>{
      ';': _countUnquoted(sample, ';'),
      ',': _countUnquoted(sample, ','),
      '\t': _countUnquoted(sample, '\t'),
    };
    var best = fallback.isEmpty ? ',' : fallback;
    var bestCount = counts[best] ?? 0;
    for (final e in counts.entries) {
      if (e.value > bestCount) {
        best = e.key;
        bestCount = e.value;
      }
    }
    return bestCount > 0 ? best : (fallback.isEmpty ? ',' : fallback);
  }

  static int _countUnquoted(String line, String delimiter) {
    var n = 0;
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && ch == delimiter) n++;
    }
    return n;
  }

  /// Parser CSV mínimo con soporte de comillas dobles (RFC4180 básico).
  static List<String> _parseCsvLine(String line, String delimiter) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          final nextIsQuote =
              i + 1 < line.length && line[i + 1] == '"';
          if (nextIsQuote) {
            buf.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buf.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == delimiter) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }

  static Uint8List _sanitizeInvalidNumFmtIds(Uint8List bytes) =>
      _sanitize(bytes);

  static String _parseErrorMessage(String raw) {
    return raw.replaceFirst(RegExp(r'^Fila \d+:\s*'), '').trim();
  }

  static Uint8List _sanitize(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? stylesFile;
    for (final f in archive) {
      if (f.name == 'xl/styles.xml') {
        stylesFile = f;
        break;
      }
    }
    if (stylesFile == null) return bytes;
    final content = stylesFile.content;
    if (content is! List<int>) return bytes;
    var xml = String.fromCharCodes(content);

    final block = RegExp(
      r'<numFmts[^>]*count="(\d+)"[^>]*>([\s\S]*?)</numFmts>',
      multiLine: true,
    );
    final match = block.firstMatch(xml);
    if (match == null) return bytes;

    final inner = match.group(2) ?? '';
    final fmtExp = RegExp(r'<numFmt\b[^>]*\/>');
    final fmtMatches = fmtExp.allMatches(inner).toList();
    if (fmtMatches.isEmpty) return bytes;

    final kept = <String>[];
    for (final m in fmtMatches) {
      final tag = m.group(0) ?? '';
      final idMatch = RegExp(r'numFmtId="(\d+)"').firstMatch(tag);
      final id = int.tryParse(idMatch?.group(1) ?? '');
      if (id == null) continue;
      if (id >= 164) kept.add(tag);
    }

    final replacement = kept.isEmpty
        ? ''
        : '<numFmts count="${kept.length}">${kept.join()}</numFmts>';
    xml = xml.replaceRange(match.start, match.end, replacement);

    final fixedArchive = Archive();
    for (final f in archive) {
      if (f.name == 'xl/styles.xml') {
        final fixed = Uint8List.fromList(xml.codeUnits);
        fixedArchive.addFile(ArchiveFile(f.name, fixed.length, fixed));
      } else {
        fixedArchive.addFile(f);
      }
    }

    final out = ZipEncoder().encode(fixedArchive);
    if (out == null) return bytes;
    return Uint8List.fromList(out);
  }
}

class _TabularData {
  const _TabularData({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}
