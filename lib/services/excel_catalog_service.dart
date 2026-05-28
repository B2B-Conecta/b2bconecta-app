import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import '../models/part_model.dart';
import '../utils/product_volume_tiers.dart';

/// Fila parseada de la plantilla de inventario (.xlsx).
class ExcelInventoryRow {
  const ExcelInventoryRow({
    required this.rowIndex,
    required this.sku,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.stock,
    this.categoria,
    this.compatibilidad,
    this.urlImagen,
    this.precioOfertaUsd,
    this.usdPaymentDiscountPct,
    this.tramosVolumenJson,
  });

  final int rowIndex;
  final String sku;
  final String nombre;
  final String? descripcion;
  final double precio;
  final int stock;
  final String? categoria;
  final String? compatibilidad;
  final String? urlImagen;
  final double? precioOfertaUsd;
  final double? usdPaymentDiscountPct;
  final String? tramosVolumenJson;

  /// `discount_rules` listo para Supabase.
  Map<String, dynamic>? get discountRules => buildProductDiscountRules(
        volumeTiers: parseProductVolumeTiers(
          parseVolumeTiersJsonCell(tramosVolumenJson),
        ),
        usdPaymentDiscountPct: usdPaymentDiscountPct,
      );
}

/// Genera y lee plantillas Excel para carga masiva de inventario.
class ExcelCatalogService {
  ExcelCatalogService._();

  /// Cabeceras exportadas en la plantilla (orden fijo).
  /// Obligatorias en cada fila de datos: sku, nombre, precio, stock.
  /// El resto se etiqueta como "(opcional)" para guiar la carga masiva.
  static const templateHeaders = [
    'sku',
    'nombre',
    'descripcion (opcional)',
    'precio',
    'precio_oferta_usd (opcional)',
    'descuento_pago_usd_pct (opcional)',
    'tramos_volumen_json (opcional)',
    'stock',
    'categoria (opcional)',
    'compatibilidad (opcional)',
    'url_imagen (opcional)',
  ];

  /// Bytes de un .xlsx con cabeceras (columnas alineadas al formulario y a BD).
  static Uint8List buildTemplateBytes() {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow(
      templateHeaders.map((h) => TextCellValue(h)).toList(),
    );
    // Fila ignorada al importar (SKU que empieza por "EJEMPLO").
    sheet.appendRow(
      [
        TextCellValue('EJEMPLO-001'),
        TextCellValue('Repuesto de muestra (puede borrar esta fila)'),
        TextCellValue('Descripción opcional'),
        TextCellValue('12.50'),
        TextCellValue('10.99'),
        TextCellValue('2'),
        TextCellValue(
          '{"volume_tiers":[{"min_units":12,"percent_discount":5}]}',
        ),
        TextCellValue('10'),
        TextCellValue('Motor'),
        TextCellValue('CG150, CG125'),
        TextCellValue(''),
      ],
    );
    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('No se pudo generar el archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  /// Exporta filas reales del inventario del importador con el mismo layout
  /// que la plantilla de carga masiva.
  static Uint8List buildInventoryExportBytes(List<PartModel> parts) {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow(
      templateHeaders.map((h) => TextCellValue(h)).toList(),
    );

    for (final p in parts) {
      final tiers = parseProductVolumeTiers(p.discountRules);
      final tiersJson = tiers.isEmpty
          ? ''
          : jsonEncode({
              'volume_tiers': tiers.map((t) => t.toJson()).toList(),
            });
      final usdPct = parseUsdPaymentDiscountPct(p.discountRules);
      sheet.appendRow(
        [
          TextCellValue((p.sku ?? '').trim()),
          TextCellValue(p.nombre),
          TextCellValue(p.descripcion ?? ''),
          TextCellValue(p.precio.toStringAsFixed(2)),
          TextCellValue(
            p.salePriceUsd == null ? '' : p.salePriceUsd!.toStringAsFixed(2),
          ),
          TextCellValue(
            usdPct == null
                ? ''
                : usdPct.toStringAsFixed(
                    usdPct.truncateToDouble() == usdPct ? 0 : 1,
                  ),
          ),
          TextCellValue(tiersJson),
          TextCellValue('${p.stock}'),
          TextCellValue(p.category ?? ''),
          TextCellValue(p.compatibilidad ?? ''),
          TextCellValue(p.imagenUrl ?? ''),
        ],
      );
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('No se pudo generar el archivo Excel de inventario.');
    }
    return Uint8List.fromList(bytes);
  }

  /// Lee filas de datos (omite la fila de cabecera).
  static List<ExcelInventoryRow> parseInventoryBytes(Uint8List bytes) {
    late final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      final detail = e.toString();
      if (detail.contains('custom numFmtId starts at 164')) {
        try {
          final sanitized = _sanitizeInvalidNumFmtIds(bytes);
          excel = Excel.decodeBytes(sanitized);
        } catch (_) {
          throw FormatException(
            'No se pudo leer el archivo .xlsx. '
            'Abre la hoja y guarda como "Libro de Excel (*.xlsx)" '
            'sin formatos personalizados, luego vuelve a intentar. '
            'Detalle: $e',
          );
        }
      } else {
        throw FormatException(
          'No se pudo leer el archivo .xlsx. '
          'Abre la hoja y guarda como "Libro de Excel (*.xlsx)" '
          'sin formatos personalizados, luego vuelve a intentar. '
          'Detalle: $e',
        );
      }
    }
    if (excel.tables.isEmpty) {
      throw const FormatException('El archivo no contiene hojas.');
    }
    final sheet = excel.tables.values.first;
    if (sheet.maxRows < 2) {
      return [];
    }

    final headerRow = sheet.rows[0];
    final colIndex = <String, int>{};
    for (var c = 0; c < headerRow.length; c++) {
      final raw = _cellText(headerRow[c]);
      final key = raw.trim().toLowerCase();
      if (key.isEmpty) continue;
      colIndex[key] = c;
      final normalized = _normalizeHeaderKey(key);
      if (normalized.isNotEmpty) {
        colIndex[normalized] = c;
      }
    }

    void needColumn(String name) {
      if (!colIndex.containsKey(name)) {
        throw FormatException('Falta la columna obligatoria: $name');
      }
    }

    needColumn('sku');
    needColumn('nombre');
    needColumn('precio');
    needColumn('stock');

    int? headerCol(String a, [String? b]) {
      final i = colIndex[a];
      if (i != null) return i;
      if (b != null) return colIndex[b];
      return null;
    }

    final urlCol = headerCol('url_imagen', 'image_url');
    final compatCol = colIndex['compatibilidad'];
    final ofertaCol = headerCol('precio_oferta_usd', 'precio_oferta');
    final usdPctCol = headerCol(
      'descuento_pago_usd_pct',
      'usd_payment_discount_pct',
    );
    final tiersCol = headerCol('tramos_volumen_json', 'tramos_volumen');

    final out = <ExcelInventoryRow>[];
    for (var r = 1; r < sheet.maxRows; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty) continue;
      final sku = _cellText(_col(row, colIndex['sku'])).trim();
      if (sku.isEmpty) continue;
      if (sku.toUpperCase().startsWith('EJEMPLO')) continue;

      final nombre = _cellText(_col(row, colIndex['nombre'])).trim();
      if (nombre.isEmpty) {
        throw FormatException('Fila ${r + 1}: nombre vacío para SKU $sku');
      }

      final descRaw = colIndex['descripcion'];
      final descripcion = descRaw != null
          ? _nullableText(_cellText(_col(row, descRaw)))
          : null;

      final precioStr = _cellText(_col(row, colIndex['precio'])).trim();
      final precio = double.tryParse(precioStr.replaceAll(',', '.'));
      if (precio == null || precio < 0) {
        throw FormatException(
          'Fila ${r + 1}: precio inválido para SKU $sku',
        );
      }

      final stockStr = _cellText(_col(row, colIndex['stock'])).trim();
      final stock = int.tryParse(stockStr);
      if (stock == null || stock < 0) {
        throw FormatException(
          'Fila ${r + 1}: stock inválido para SKU $sku',
        );
      }

      final catRaw = colIndex['categoria'];
      final categoria =
          catRaw != null ? _nullableText(_cellText(_col(row, catRaw))) : null;

      final compatibilidad = compatCol != null
          ? _nullableText(_cellText(_col(row, compatCol)))
          : null;

      final urlImagen =
          urlCol != null ? _nullableText(_cellText(_col(row, urlCol))) : null;

      double? precioOferta;
      if (ofertaCol != null) {
        final ofertaStr = _cellText(_col(row, ofertaCol)).trim();
        if (ofertaStr.isNotEmpty) {
          precioOferta = double.tryParse(ofertaStr.replaceAll(',', '.'));
          if (precioOferta == null || precioOferta <= 0) {
            throw FormatException(
              'Fila ${r + 1}: precio_oferta_usd inválido para SKU $sku',
            );
          }
          if (precioOferta >= precio) {
            throw FormatException(
              'Fila ${r + 1}: precio_oferta_usd debe ser menor que precio para SKU $sku',
            );
          }
        }
      }

      final tramosJson = tiersCol != null
          ? _nullableText(_cellText(_col(row, tiersCol)))
          : null;

      double? usdPaymentDiscountPct;
      if (usdPctCol != null) {
        final pctStr = _cellText(_col(row, usdPctCol)).trim();
        if (pctStr.isNotEmpty) {
          usdPaymentDiscountPct =
              double.tryParse(pctStr.replaceAll(',', '.'));
          if (usdPaymentDiscountPct == null ||
              usdPaymentDiscountPct <= 0 ||
              usdPaymentDiscountPct >= 100) {
            throw FormatException(
              'Fila ${r + 1}: descuento_pago_usd_pct inválido para SKU $sku '
              '(use un número entre 0 y 100, sin incluir los extremos).',
            );
          }
        }
      }
      if (usdPaymentDiscountPct == null && tramosJson != null) {
        final fromJson = parseVolumeTiersJsonCell(tramosJson);
        usdPaymentDiscountPct = parseUsdPaymentDiscountPct(fromJson);
      }

      out.add(
        ExcelInventoryRow(
          rowIndex: r + 1,
          sku: sku,
          nombre: nombre,
          descripcion: descripcion,
          precio: precio,
          stock: stock,
          categoria: categoria,
          compatibilidad: compatibilidad,
          urlImagen: urlImagen,
          precioOfertaUsd: precioOferta,
          usdPaymentDiscountPct: usdPaymentDiscountPct,
          tramosVolumenJson: tramosJson,
        ),
      );
    }
    return out;
  }

  static Data? _col(List<Data?> row, int? i) {
    if (i == null || i < 0 || i >= row.length) return null;
    return row[i];
  }

  static String? _nullableText(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static String _cellText(Data? cell) {
    if (cell == null) return '';
    final v = cell.value;
    if (v == null) return '';
    return v.toString();
  }

  static String _normalizeHeaderKey(String raw) {
    var key = raw.trim().toLowerCase();
    if (key.isEmpty) return '';
    key = key
        .replaceAll('(opcional)', '')
        .replaceAll('(optional)', '')
        .replaceAll('(obligatorio)', '')
        .replaceAll('(required)', '')
        .replaceAll('*', '')
        .trim();
    // Compactar dobles espacios por si el usuario edita manualmente.
    key = key.replaceAll(RegExp(r'\s+'), ' ');
    return key;
  }

  /// Corrige archivos que declaran numFmt custom con IDs reservados (<164).
  /// Algunos exportadores generan ese XML y rompe el parser de `excel`.
  static Uint8List _sanitizeInvalidNumFmtIds(Uint8List bytes) {
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
        final nf = ArchiveFile(f.name, fixed.length, fixed)
          ..comment = f.comment
          ..compress = f.compress
          ..crc32 = f.crc32
          ..isFile = f.isFile
          ..isSymbolicLink = f.isSymbolicLink
          ..lastModTime = f.lastModTime
          ..mode = f.mode
          ..nameOfLinkedFile = f.nameOfLinkedFile
          ..ownerId = f.ownerId
          ..groupId = f.groupId;
        fixedArchive.addFile(nf);
      } else {
        fixedArchive.addFile(f);
      }
    }

    final out = ZipEncoder().encode(fixedArchive);
    if (out == null) return bytes;
    return Uint8List.fromList(out);
  }
}
