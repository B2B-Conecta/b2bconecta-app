import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import 'catalog_import/catalog_import_field.dart';
import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'catalog_import_header_guess.dart';
import 'catalog_import_validator.dart';
import 'excel_catalog_service.dart';

/// Lee archivos Excel/CSV arbitrarios y aplica mapeo dinámico fila a fila.
///
/// Diseñado para lotes grandes (9k+ filas): procesa en chunks configurables
/// sin materializar todo el payload RPC en memoria.
class FlexibleCatalogImportService {
  FlexibleCatalogImportService._();

  /// Filas en la tarjeta compacta del wizard (mapeo).
  static const defaultSampleRowCount = 5;

  /// Máximo de filas al abrir «Ver detalles de la carga».
  /// Suficiente para catálogos típicos; archivos enormes se truncan con aviso.
  static const detailsPreviewMaxRows = 2000;
  static const _headerSearchLimit = 100;
  static final _zeroPadFormat = RegExp(r'^0{2,}$');

  /// Detects the source layout once and keeps physical row numbers intact.
  static ({CatalogImportFileMeta file, CatalogImportPreview preview})
      prepareFile({
    required Uint8List bytes,
    required CatalogImportFileMeta meta,
    bool detectHeader = true,
  }) {
    final table = _readTabular(bytes, meta, detectHeader: detectHeader);
    final headerRow = table.headerIndex + 1;
    final file = CatalogImportFileMeta(
      name: meta.name,
      format: meta.format,
      sheetName: table.sheetName ?? meta.sheetName,
      headerRow: headerRow,
      dataStartsAtRow: detectHeader ? headerRow + 1 : meta.dataStartsAtRow,
      encoding: meta.encoding,
      csvDelimiter: table.delimiter ?? meta.csvDelimiter,
    );
    return (file: file, preview: _preview(table, file));
  }

  /// Paso 1: extrae cabeceras y filas de muestra para el wizard de mapeo.
  ///
  /// [sampleRowCount] limita cuántas filas se materializan en [sampleRows]
  /// (el conteo total sigue en [totalDataRowsEstimate]).
  static CatalogImportPreview previewFile({
    required Uint8List bytes,
    required CatalogImportFileMeta meta,
    int sampleRowCount = defaultSampleRowCount,
    Map<int, Map<String, String>> corrections = const {},
  }) =>
      _preview(
        _readTabular(bytes, meta),
        meta,
        sampleRowCount: sampleRowCount,
        corrections: corrections,
      );

  static CatalogImportPreview _preview(
    _TabularData table,
    CatalogImportFileMeta meta, {
    int sampleRowCount = defaultSampleRowCount,
    Map<int, Map<String, String>> corrections = const {},
  }) {
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
    final rowNumbers = <int>[];
    var dataRows = 0;
    final cap = sampleRowCount < 1 ? defaultSampleRowCount : sampleRowCount;

    for (var r = dataStart; r < table.rows.length; r++) {
      final raw = table.rows[r];
      if (_rowIsEmpty(raw)) continue;
      dataRows++;
      if (samples.length < cap) {
        samples.add({..._zipRow(headers, raw), ...?corrections[r + 1]});
        rowNumbers.add(r + 1);
      }
    }

    return CatalogImportPreview(
      headers: headers,
      sampleRows: samples,
      sampleRowNumbers: rowNumbers,
      totalDataRowsEstimate: dataRows,
    );
  }

  /// Lee los valores originales de las filas que se pueden corregir.
  static Map<int, Map<String, String>> readRows({
    required Uint8List bytes,
    required CatalogImportFileMeta meta,
    required Set<int> rowNumbers,
  }) {
    final table = _readTabular(bytes, meta);
    return {
      for (final row in rowNumbers)
        if (row >= meta.dataStartsAtRow && row <= table.rows.length)
          row: _zipRow(table.headers, table.rows[row - 1]),
    };
  }

  /// Paso 2: parsea + valida el archivo completo en lotes.
  static Stream<CatalogImportParseBatch> parseInBatches({
    required Uint8List bytes,
    required CatalogImportMapping mapping,
    Map<int, Map<String, String>> corrections = const {},
    void Function(String skuKey)? onSourceSku,
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
    final skuColumn = mapping.columnMap[CatalogImportField.sku.key]!.source;

    Stream<CatalogImportParseBatch> stream() async* {
      final buffer = <CatalogImportNormalizedRow>[];
      final fileSkus = <String>{};

      for (var r = dataStart; r < table.rows.length; r++) {
        final rawCells = table.rows[r];
        if (_rowIsEmpty(rawCells)) continue;

        final rawByHeader = _zipRow(headers, rawCells);
        final corrected = corrections[r + 1];
        if (corrected != null) rawByHeader.addAll(corrected);
        final sku = rawByHeader[skuColumn]?.trim().toLowerCase();
        if (sku != null && sku.isNotEmpty) onSourceSku?.call(sku);
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
          yield CatalogImportValidator.validateBatch(buffer,
              fileSkus: fileSkus, maxErrors: buffer.length);
          buffer.clear();
        }
      }

      if (buffer.isNotEmpty) {
        yield CatalogImportValidator.validateBatch(buffer,
            fileSkus: fileSkus, maxErrors: buffer.length);
      }
    }

    return stream();
  }

  static Future<Uint8List> buildReviewedWorkbook({
    required Uint8List bytes,
    required CatalogImportMapping mapping,
    Map<int, Map<String, String>> corrections = const {},
  }) async {
    final rows = <List<String>>[];
    final warrantyMapped =
        mapping.columnMap.containsKey(CatalogImportField.hasWarranty.key);
    await for (final batch in parseInBatches(
      bytes: bytes,
      mapping: mapping,
      corrections: corrections,
    )) {
      if (batch.errors.isNotEmpty) {
        throw const FormatException(
            'Corrige las filas con errores antes de descargar.');
      }
      for (final row in batch.validRows) {
        final warrantyDays = row.customFields['warranty_days'];
        rows.add([
          row.sku,
          row.name,
          row.description ?? '',
          row.priceUsd.toString(),
          row.salePriceUsd?.toString() ?? '',
          row.stock.toString(),
          row.minOrderQty?.toString() ?? '',
          row.parentSku ?? '',
          row.variantAttributeName ?? '',
          row.variantAttributeValue ?? '',
          row.variantAttributes.isEmpty
              ? ''
              : jsonEncode(row.variantAttributes),
          row.category ?? '',
          row.compatibility ?? '',
          row.imageUrl ?? '',
          if (warrantyMapped)
            warrantyDays?.toString() ?? (row.hasWarranty ? 'si' : 'no')
          else
            '',
          if (row.isActive case final active?) active ? 'si' : 'no' else '',
        ]);
      }
    }
    if (rows.isEmpty)
      throw const FormatException(
          'El archivo no contiene repuestos para descargar.');
    return ExcelCatalogService.buildInventoryRowsBytes(rows);
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
        CatalogImportField.parentSku.key: CatalogImportColumnBinding(
          source: 'parent_sku (opcional)',
        ),
        CatalogImportField.variantAttributeName.key: CatalogImportColumnBinding(
          source: 'atributo (opcional)',
        ),
        CatalogImportField.variantAttributeValue.key:
            CatalogImportColumnBinding(
          source: 'valor_atributo (opcional)',
        ),
        CatalogImportField.variantAttributes.key: CatalogImportColumnBinding(
          source: 'atributos (opcional)',
        ),
        CatalogImportField.category.key: CatalogImportColumnBinding(
          source: 'categoria (opcional)',
        ),
        CatalogImportField.compatibility.key: CatalogImportColumnBinding(
          source: 'compatibilidad (opcional)',
        ),
        CatalogImportField.imageUrl.key: CatalogImportColumnBinding(
          source: 'url_imagen (opcional)',
        ),
        CatalogImportField.hasWarranty.key: CatalogImportColumnBinding(
          source: 'garantia (opcional)',
          transform: CatalogImportTransform.booleanSiNo,
        ),
        CatalogImportField.isActive.key: CatalogImportColumnBinding(
          source: 'activo (opcional)',
          transform: CatalogImportTransform.booleanSiNo,
        ),
        CatalogImportField.usdPaymentDiscountPct.key:
            CatalogImportColumnBinding(
          source: 'descuento_pago_usd_pct (opcional)',
          transform: CatalogImportTransform.decimalComma,
        ),
      },
    );
  }

  static _TabularData _readTabular(
    Uint8List bytes,
    CatalogImportFileMeta meta, {
    bool detectHeader = false,
  }) {
    if (meta.format == CatalogImportFileFormat.csv) {
      return _readCsv(bytes, meta, detectHeader: detectHeader);
    }
    return _readXlsx(bytes, meta, detectHeader: detectHeader);
  }

  static _TabularData _readXlsx(
    Uint8List bytes,
    CatalogImportFileMeta meta, {
    required bool detectHeader,
  }) {
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

    final sheets = excel.tables;
    var sheetName = meta.sheetName ?? sheets.keys.first;
    var headerIdx = meta.headerRow - 1;
    if (detectHeader) {
      var bestScore = -1;
      for (final name in meta.sheetName == null ? sheets.keys : [sheetName]) {
        final sheet = sheets[name];
        if (sheet == null || sheet.maxRows == 0) continue;
        final candidate = _findHeader(sheet.rows
            .take(_headerSearchLimit)
            .map((row) => row.map(_cellText).toList()));
        if (candidate.score > bestScore) {
          bestScore = candidate.score;
          sheetName = name;
          headerIdx = candidate.index;
        }
        if (bestScore == catalogImportRequiredFields.length) break;
      }
    }
    final sheet = sheets[sheetName];
    if (sheet == null) throw FormatException('Hoja no encontrada: $sheetName');
    if (headerIdx < 0 || headerIdx >= sheet.maxRows) {
      throw FormatException('Fila de cabecera inválida: ${headerIdx + 1}');
    }

    final sheetRows = sheet.rows;
    final headers = _uniqueHeaders(sheetRows[headerIdx].map(_cellText));

    final rows = <List<String>>[];
    for (final src in sheetRows) {
      final out = List<String>.filled(headers.length, '');
      for (var c = 0; c < headers.length; c++) {
        out[c] = _cellText(_col(src, c));
      }
      rows.add(out);
    }

    return _TabularData(
        headers: headers,
        rows: rows,
        headerIndex: headerIdx,
        sheetName: sheetName);
  }

  static _TabularData _readCsv(
    Uint8List bytes,
    CatalogImportFileMeta meta, {
    required bool detectHeader,
  }) {
    final text = _decodeText(bytes, meta.encoding);
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty) {
      return const _TabularData(headers: [], rows: []);
    }

    var delimiter = detectCsvDelimiter(
      lines.skip(meta.headerRow - 1).firstOrNull ?? '',
      fallback: meta.csvDelimiter,
    );
    var headerIdx = meta.headerRow - 1;
    if (detectHeader) {
      final sample = lines.take(_headerSearchLimit);
      var bestScore = -1;
      for (final candidateDelimiter in {delimiter, ';', ',', '\t'}) {
        final candidate = _findHeader(
            sample.map((line) => _parseCsvLine(line, candidateDelimiter)));
        if (candidate.score > bestScore) {
          bestScore = candidate.score;
          headerIdx = candidate.index;
          delimiter = candidateDelimiter;
        }
        if (bestScore == catalogImportRequiredFields.length) break;
      }
      if (bestScore == 0) {
        delimiter = detectCsvDelimiter(lines[headerIdx], fallback: delimiter);
      }
    }
    if (headerIdx < 0 || headerIdx >= lines.length) {
      throw FormatException('Fila de cabecera inválida: ${headerIdx + 1}');
    }
    final parsed = lines.map((l) => _parseCsvLine(l, delimiter)).toList();
    final headers = _uniqueHeaders(parsed[headerIdx]);

    return _TabularData(
        headers: headers,
        rows: parsed,
        headerIndex: headerIdx,
        delimiter: delimiter);
  }

  static ({int index, int score}) _findHeader(Iterable<List<String>> rows) {
    var firstNonEmpty = -1;
    var bestIndex = -1;
    var bestScore = 0;
    for (final (index, row) in rows.indexed) {
      if (_rowIsEmpty(row)) continue;
      if (firstNonEmpty < 0) firstNonEmpty = index;
      final score = CatalogImportHeaderGuess.headerScore(row);
      if (score > bestScore) {
        bestIndex = index;
        bestScore = score;
        if (score == catalogImportRequiredFields.length) break;
      }
    }
    return (
      index: bestIndex >= 0
          ? bestIndex
          : firstNonEmpty.clamp(0, _headerSearchLimit),
      score: firstNonEmpty < 0 ? -1 : bestScore
    );
  }

  static List<String> _uniqueHeaders(Iterable<String> cells) {
    final names = cells
        .map((raw) => raw.replaceFirst(RegExp(r'^\uFEFF'), '').trim())
        .toList();
    final reserved = names.toSet();
    final used = <String>{};
    return [
      for (final (index, name) in names.indexed)
        if (name.isNotEmpty && used.add(name))
          name
        else
          _nextHeader(name.isEmpty ? 'column_$index' : name, reserved, used),
    ];
  }

  static String _nextHeader(
      String base, Set<String> reserved, Set<String> used) {
    var name = base;
    var suffix = 2;
    while (reserved.contains(name) || !used.add(name)) {
      name = '$base (${suffix++})';
    }
    return name;
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
    final format = cell.cellStyle?.numberFormat.formatCode;
    if (format != null && _zeroPadFormat.hasMatch(format)) {
      final value = switch (v) {
        IntCellValue(:final value) => value,
        DoubleCellValue(:final value)
            when value.isFinite && value == value.truncateToDouble() =>
          value.toInt(),
        _ => null,
      };
      if (value != null && value >= 0) {
        return value.toString().padLeft(format.length, '0');
      }
    }
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
          final nextIsQuote = i + 1 < line.length && line[i + 1] == '"';
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
  const _TabularData(
      {required this.headers,
      required this.rows,
      this.headerIndex = 0,
      this.sheetName,
      this.delimiter});
  final List<String> headers;
  final List<List<String>> rows;
  final int headerIndex;
  final String? sheetName;
  final String? delimiter;
}
