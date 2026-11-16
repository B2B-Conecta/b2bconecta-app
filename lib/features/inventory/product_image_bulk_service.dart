import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'product_images.dart';

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

  int get uploadableSkuCount {
    final excluded = [...unknownSkus, ...overLimitSkus]
        .map((sku) => sku.toLowerCase())
        .toSet();
    return bySku.keys.where((sku) => !excluded.contains(sku)).length;
  }

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
    bool keepAmbiguousForReview = false,
  }) {
    const maxZipBytes = 50 * 1024 * 1024;
    const maxExtractedBytes = 100 * 1024 * 1024;
    if (bytes.length > maxZipBytes) {
      throw const FormatException(
          'El ZIP supera 50 MiB. Divide las fotos en varios archivos.');
    }
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw FormatException('No se pudo leer el ZIP: $e');
    }

    final files = <ProductImageBulkFile>[];
    final invalid = <String>[];
    var extractedBytes = 0;

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name.contains('__MACOSX') || name.endsWith('.DS_Store')) continue;

      var parsed = parseProductImageFilename(name);
      if (parsed == null) {
        invalid.add(name);
        continue;
      }

      final dot = name.lastIndexOf('.');
      final ext = name.substring(dot + 1).toLowerCase();
      final filename = name.replaceAll(r'\', '/').split('/').last;
      final exactSku = filename.substring(0, filename.lastIndexOf('.')).trim();
      if (parsed.slot != 1 && knownSkuKeys.contains(exactSku.toLowerCase())) {
        if (knownSkuKeys.contains(parsed.sku.toLowerCase())) {
          if (!keepAmbiguousForReview) {
            invalid.add('$name: SKU ambiguo entre $exactSku y ${parsed.sku}');
            continue;
          }
          parsed = const ProductImageFilenameParse(sku: '', slot: 1);
        } else {
          parsed = ProductImageFilenameParse(sku: exactSku, slot: 1);
        }
      }
      if (entry.size > 10 * 1024 * 1024) {
        invalid.add('$name: supera 10 MiB');
        continue;
      }
      extractedBytes += entry.size;
      if (extractedBytes > maxExtractedBytes) {
        throw const FormatException(
            'Las fotos superan 100 MiB al descomprimir. Divide el ZIP.');
      }
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

    if (files.isEmpty && invalid.isEmpty) {
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
      if (e.value.length > kMaxProductImages ||
          e.value.map((file) => file.slot).toSet().length != e.value.length) {
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

  /// Agrupa archivos por slot (1..3); los conflictos se deben rechazar antes de subir.
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
