import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../utils/product_images.dart';

/// Archivo de imagen extraído de un ZIP para carga masiva.
class ProductImageBulkFile {
  const ProductImageBulkFile({
    required this.pathInZip,
    required this.bytes,
    required this.extension,
    required this.sku,
    required this.slot,
  });

  final String pathInZip;
  final Uint8List bytes;
  final String extension;
  final String sku;
  final int slot;
}

/// Resumen previo a importar fotos masivas.
class ProductImageBulkPreview {
  const ProductImageBulkPreview({
    required this.files,
    required this.bySku,
    required this.unknownSkus,
    required this.overLimitSkus,
    required this.invalidEntries,
  });

  final List<ProductImageBulkFile> files;
  final Map<String, List<ProductImageBulkFile>> bySku;
  final List<String> unknownSkus;
  final List<String> overLimitSkus;
  final List<String> invalidEntries;

  int get skuCount => bySku.length;
  int get matchedSkuCount => bySku.length - unknownSkus.length;

  factory ProductImageBulkPreview.empty() => const ProductImageBulkPreview(
        files: [],
        bySku: {},
        unknownSkus: [],
        overLimitSkus: [],
        invalidEntries: [],
      );
}

class ProductImageBulkService {
  ProductImageBulkService._();

  static ProductImageBulkPreview parseZipBytes(
    Uint8List bytes, {
    required Set<String> knownSkuKeys,
  }) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw FormatException('No se pudo leer el ZIP: $e');
    }

    final files = <ProductImageBulkFile>[];
    final invalid = <String>[];

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name.contains('__MACOSX') || name.endsWith('.DS_Store')) continue;

      final parsed = parseProductImageFilename(name);
      if (parsed == null) {
        invalid.add(name);
        continue;
      }

      final dot = name.lastIndexOf('.');
      final ext = name.substring(dot + 1).toLowerCase();
      final content = entry.content;
      if (content is! List<int> || content.isEmpty) {
        invalid.add(name);
        continue;
      }

      files.add(
        ProductImageBulkFile(
          pathInZip: name,
          bytes: Uint8List.fromList(content),
          extension: ext == 'jpg' ? 'jpeg' : ext,
          sku: parsed.sku,
          slot: parsed.slot,
        ),
      );
    }

    if (files.isEmpty) {
      throw const FormatException(
        'El ZIP no contiene imágenes válidas. '
        'Nombra los archivos como SKU.jpg, SKU_2.jpg o SKU_3.jpg',
      );
    }

    final bySku = <String, List<ProductImageBulkFile>>{};
    for (final f in files) {
      final key = f.sku.toLowerCase();
      bySku.putIfAbsent(key, () => []).add(f);
    }

    final unknown = <String>[];
    final overLimit = <String>[];
    for (final e in bySku.entries) {
      if (!knownSkuKeys.contains(e.key)) {
        unknown.add(e.value.first.sku);
      }
      if (e.value.length > kMaxProductImages) {
        overLimit.add(e.value.first.sku);
      }
    }

    unknown.sort();
    overLimit.sort();

    return ProductImageBulkPreview(
      files: files,
      bySku: bySku,
      unknownSkus: unknown,
      overLimitSkus: overLimit,
      invalidEntries: invalid,
    );
  }

  /// Agrupa archivos por slot (1..3); si hay duplicado de slot, gana el último.
  static Map<int, ProductImageBulkFile> filesBySlot(
    List<ProductImageBulkFile> files,
  ) {
    final map = <int, ProductImageBulkFile>{};
    for (final f in files) {
      if (f.slot >= 1 && f.slot <= kMaxProductImages) {
        map[f.slot] = f;
      }
    }
    return map;
  }
}
