/// Utilidades para fotos de producto (máx. [kMaxProductImages]).
const kMaxProductImages = 3;

const _allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

bool isAllowedProductImageExtension(String ext) {
  var e = ext.replaceAll('.', '').toLowerCase();
  if (e == 'jpg') e = 'jpeg';
  return _allowedImageExtensions.contains(e);
}

/// Parsea `products.image_urls` desde PostgREST.
List<String> parseProductImageUrlsJson(dynamic raw, {String? legacyImageUrl}) {
  final out = <String>[];
  if (raw is List) {
    for (final e in raw) {
      final s = e?.toString().trim() ?? '';
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
      if (out.length >= kMaxProductImages) break;
    }
  }
  if (out.isEmpty) {
    final legacy = legacyImageUrl?.trim();
    if (legacy != null && legacy.isNotEmpty) return [legacy];
  }
  return out;
}

List<String> normalizeProductImageUrls(Iterable<String> urls) {
  final out = <String>[];
  for (final u in urls) {
    final s = u.trim();
    if (s.isEmpty) continue;
    if (out.contains(s)) continue;
    out.add(s);
    if (out.length >= kMaxProductImages) break;
  }
  return out;
}

String? productCoverImageUrl(List<String> urls, {String? legacy}) {
  if (urls.isNotEmpty) return urls.first;
  final l = legacy?.trim();
  return (l == null || l.isEmpty) ? null : l;
}

/// Resultado de parsear un nombre de archivo de carga masiva.
class ProductImageFilenameParse {
  const ProductImageFilenameParse({
    required this.sku,
    required this.slot,
  });

  final String sku;
  final int slot;
}

/// `ABC123.jpg` → slot 1; `ABC123_2.png` → slot 2; `ABC123-3.webp` → slot 3.
ProductImageFilenameParse? parseProductImageFilename(String path) {
  var name = path.replaceAll('\\', '/');
  if (name.contains('/')) {
    name = name.split('/').last;
  }
  if (name.startsWith('.')) return null;

  final dot = name.lastIndexOf('.');
  if (dot <= 0) return null;

  final ext = name.substring(dot + 1).toLowerCase();
  if (!isAllowedProductImageExtension(ext)) return null;

  var stem = name.substring(0, dot).trim();
  if (stem.isEmpty) return null;

  var slot = 1;
  final suffix2 = RegExp(r'[_-]2$').firstMatch(stem);
  final suffix3 = RegExp(r'[_-]3$').firstMatch(stem);
  if (suffix3 != null) {
    slot = 3;
    stem = stem.substring(0, stem.length - 2);
  } else if (suffix2 != null) {
    slot = 2;
    stem = stem.substring(0, stem.length - 2);
  }

  final sku = stem.trim();
  if (sku.isEmpty) return null;
  return ProductImageFilenameParse(sku: sku, slot: slot);
}

enum ProductImageBulkMergeMode {
  replace,
  fillEmptyOnly,
  append,
}

extension ProductImageBulkMergeModeX on ProductImageBulkMergeMode {
  String get label => switch (this) {
        ProductImageBulkMergeMode.replace => 'Reemplazar fotos',
        ProductImageBulkMergeMode.fillEmptyOnly => 'Solo productos sin foto',
        ProductImageBulkMergeMode.append => 'Añadir sin borrar',
      };

  String get subtitle => switch (this) {
        ProductImageBulkMergeMode.replace =>
          'Las fotos del ZIP sustituyen las actuales (hasta 3).',
        ProductImageBulkMergeMode.fillEmptyOnly =>
          'Solo actualiza productos que aún no tienen ninguna imagen.',
        ProductImageBulkMergeMode.append =>
          'Completa slots libres sin eliminar fotos existentes.',
      };
}

/// Combina URLs existentes con nuevas según el modo elegido.
List<String> mergeProductImageUrls({
  required List<String> existing,
  required Map<int, String> newBySlot,
  required ProductImageBulkMergeMode mode,
}) {
  switch (mode) {
    case ProductImageBulkMergeMode.replace:
      final out = <String>[];
      for (var slot = 1; slot <= kMaxProductImages; slot++) {
        final u = newBySlot[slot];
        if (u != null && u.isNotEmpty) out.add(u);
      }
      return normalizeProductImageUrls(out);

    case ProductImageBulkMergeMode.fillEmptyOnly:
      if (existing.isNotEmpty) return normalizeProductImageUrls(existing);
      return mergeProductImageUrls(
        existing: const [],
        newBySlot: newBySlot,
        mode: ProductImageBulkMergeMode.replace,
      );

    case ProductImageBulkMergeMode.append:
      final slots = List<String?>.filled(kMaxProductImages, null);
      for (var i = 0; i < existing.length && i < kMaxProductImages; i++) {
        slots[i] = existing[i];
      }
      for (final e in newBySlot.entries) {
        final idx = e.key - 1;
        if (idx < 0 || idx >= kMaxProductImages) continue;
        if (slots[idx] == null || slots[idx]!.isEmpty) {
          slots[idx] = e.value;
        } else {
          for (var j = 0; j < kMaxProductImages; j++) {
            if (slots[j] == null || slots[j]!.isEmpty) {
              slots[j] = e.value;
              break;
            }
          }
        }
      }
      return normalizeProductImageUrls(
        slots.whereType<String>().where((s) => s.isNotEmpty),
      );
  }
}
