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

int _compareVariantOptions(PartModel a, PartModel b) {
  final byLabel = a.variantOptionLabel.toLowerCase().compareTo(
        b.variantOptionLabel.toLowerCase(),
      );
  if (byLabel != 0) return byLabel;
  return a.id.compareTo(b.id);
}
