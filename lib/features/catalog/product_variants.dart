import 'dart:convert';

import 'part_model.dart';

/// Una tarjeta por producto maestro. Cada variante sigue siendo un [PartModel]
/// con su SKU, precio y stock. Sin `parent_sku` la fila no se agrupa.
List<PartModel> collapseProductVariants(List<PartModel> parts) {
  final groups = <String, List<PartModel>>{};
  final order = <String>[];

  for (final part in parts) {
    final key = _groupKey(part);
    final bucket = groups[key];
    if (bucket == null) {
      groups[key] = [part];
      order.add(key);
    } else {
      bucket.add(part);
    }
  }

  return [
    for (final key in order) _collapseGroup(groups[key]!),
  ];
}

List<PartModel> sortVariantOptions(List<PartModel> options) {
  final sorted = [...options]..sort(_compareVariantOptions);
  return sorted;
}

PartModel pickLeadVariant(List<PartModel> options) {
  final available = options.where((part) => part.stockCoversMinOrder).toList();
  final pool = available.isEmpty ? options : available;
  final sorted = [...pool]..sort((a, b) {
    final byPrice = a.precio.compareTo(b.precio);
    if (byPrice != 0) return byPrice;
    return _compareVariantOptions(a, b);
  });
  return sorted.first;
}

/// Atributos de una fila: mapa JSON o, si falta, el par legado nombre/valor.
/// Si el nombre y el valor usan el separador ` / ` con la misma cantidad de
/// partes (variantes antiguas combinadas), se reconstruyen varios ejes.
Map<String, String> variantAttributesOf(PartModel part) {
  if (part.variantAttributes.isNotEmpty) {
    return Map<String, String>.from(part.variantAttributes);
  }
  return _legacyAttributes(
    part.variantAttributeName,
    part.variantAttributeValue,
  );
}

/// Ejes compartidos por la familia, en el orden de la primera opción.
List<String> variantAttributeAxes(List<PartModel> options) {
  if (options.isEmpty) return const [];
  final first = variantAttributesOf(options.first);
  if (first.isEmpty) return const [];
  final axes = first.keys.toList();
  for (final option in options.skip(1)) {
    final attrs = variantAttributesOf(option);
    for (final key in attrs.keys) {
      if (!axes.contains(key)) axes.add(key);
    }
  }
  return axes;
}

/// Valores posibles de [axis] compatibles con el resto de [selection].
List<String> availableAttributeValues({
  required List<PartModel> options,
  required String axis,
  required Map<String, String> selection,
}) {
  final values = <String>{};
  final ordered = <String>[];
  for (final option in options) {
    final attrs = variantAttributesOf(option);
    final value = attrs[axis]?.trim() ?? '';
    if (value.isEmpty) continue;
    if (!_matchesOtherAxes(attrs, selection, exceptAxis: axis)) continue;
    if (values.add(value)) ordered.add(value);
  }
  return ordered;
}

/// Elige la variante que encaja con [selection]. Si no hay exacta, prioriza
/// el eje recién cambiado y completa con la primera opción disponible.
PartModel pickVariantForAttributes({
  required List<PartModel> options,
  required Map<String, String> selection,
  String? preferredAxis,
}) {
  if (options.isEmpty) {
    throw ArgumentError('options no puede estar vacío');
  }
  final exact = options.where((option) {
    final attrs = variantAttributesOf(option);
    if (attrs.isEmpty && selection.isEmpty) return true;
    if (attrs.length != selection.length) return false;
    for (final entry in selection.entries) {
      if ((attrs[entry.key] ?? '') != entry.value) return false;
    }
    return true;
  }).toList();
  if (exact.isNotEmpty) return exact.first;

  final preferred = preferredAxis?.trim();
  var pool = options;
  if (preferred != null && preferred.isNotEmpty) {
    final want = selection[preferred];
    if (want != null && want.isNotEmpty) {
      final filtered = options.where((option) {
        return (variantAttributesOf(option)[preferred] ?? '') == want;
      }).toList();
      if (filtered.isNotEmpty) pool = filtered;
    }
  }

  PartModel? best;
  var bestScore = -1;
  for (final option in pool) {
    final attrs = variantAttributesOf(option);
    var score = 0;
    for (final entry in selection.entries) {
      if ((attrs[entry.key] ?? '') == entry.value) score++;
    }
    if (score > bestScore) {
      bestScore = score;
      best = option;
    }
  }
  return best ?? pool.first;
}

Map<String, String> selectionFromVariant(PartModel part) {
  return variantAttributesOf(part);
}

/// Celda Excel `atributos`: `Tamaño:M|Color:Rojo` o JSON `{"Tamaño":"M"}`.
Map<String, String>? parseVariantAttributesCell(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;

  if (text.startsWith('{')) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final out = <String, String>{};
        for (final entry in decoded.entries) {
          final key = entry.key.toString().trim();
          final value = entry.value?.toString().trim() ?? '';
          if (key.isEmpty || value.isEmpty) continue;
          out[key] = value;
        }
        return out.isEmpty ? null : out;
      }
    } catch (_) {
      return null;
    }
  }

  final out = <String, String>{};
  for (final chunk in text.split('|')) {
    final piece = chunk.trim();
    if (piece.isEmpty) continue;
    final sep = piece.indexOf(':');
    if (sep <= 0) return null;
    final key = piece.substring(0, sep).trim();
    final value = piece.substring(sep + 1).trim();
    if (key.isEmpty || value.isEmpty) return null;
    out[key] = value;
  }
  return out.isEmpty ? null : out;
}

String joinAttributeNames(Map<String, String> attrs) =>
    attrs.keys.join(' / ');

String joinAttributeValues(Map<String, String> attrs) =>
    attrs.values.join(' / ');

/// Serializa el mapa para RPC / plantilla Excel (`Tamaño:M|Color:Rojo`).
String formatVariantAttributesCell(Map<String, String> attrs) {
  if (attrs.isEmpty) return '';
  return attrs.entries.map((e) => '${e.key}:${e.value}').join('|');
}

/// Fotos de una fila: `image_urls` y, si no hay, la portada `image_url`.
List<String> productGalleryUrls(PartModel part) {
  if (part.imageUrls.isNotEmpty) return part.imageUrls;
  final cover = part.coverImageUrl?.trim();
  if (cover == null || cover.isEmpty) return const [];
  return [cover];
}

/// Galería de la variante elegida. Si no tiene foto, usa la del producto
/// abierto y, si tampoco tiene, la primera hermana que sí tenga.
List<String> variantGalleryUrls({
  required PartModel selected,
  required PartModel opened,
  List<PartModel> family = const [],
}) {
  final own = productGalleryUrls(selected);
  if (own.isNotEmpty) return own;
  final fromOpened = productGalleryUrls(opened);
  if (fromOpened.isNotEmpty) return fromOpened;
  for (final option in family) {
    final urls = productGalleryUrls(option);
    if (urls.isNotEmpty) return urls;
  }
  return const [];
}

String _groupKey(PartModel part) {
  final parent = part.parentSku?.trim().toLowerCase() ?? '';
  if (parent.isEmpty) return 'row:${part.id}';
  final owner = part.ownerId?.trim() ?? '';
  return 'grp:$owner:$parent';
}

PartModel _collapseGroup(List<PartModel> members) {
  if (members.length < 2) return members.first;
  final options = sortVariantOptions(members);
  final lead = pickLeadVariant(options);
  return lead.copyWith(variants: options);
}

Map<String, String> _legacyAttributes(String? nameRaw, String? valueRaw) {
  final name = nameRaw?.trim() ?? '';
  final value = valueRaw?.trim() ?? '';
  if (value.isEmpty) return const {};
  if (name.isEmpty) return {'Opción': value};

  final names = name.split(' / ').map((part) => part.trim()).toList();
  final values = value.split(' / ').map((part) => part.trim()).toList();
  if (names.length > 1 && names.length == values.length) {
    final out = <String, String>{};
    for (var i = 0; i < names.length; i++) {
      if (names[i].isEmpty || values[i].isEmpty) continue;
      out[names[i]] = values[i];
    }
    if (out.isNotEmpty) return out;
  }
  return {name: value};
}

bool _matchesOtherAxes(
  Map<String, String> attrs,
  Map<String, String> selection, {
  required String exceptAxis,
}) {
  for (final entry in selection.entries) {
    if (entry.key == exceptAxis) continue;
    final have = attrs[entry.key];
    if (have == null) continue;
    if (have != entry.value) return false;
  }
  return true;
}

int _compareVariantOptions(PartModel a, PartModel b) {
  final byLabel = a.variantOptionLabel.toLowerCase().compareTo(
        b.variantOptionLabel.toLowerCase(),
      );
  if (byLabel != 0) return byLabel;
  return a.id.compareTo(b.id);
}
