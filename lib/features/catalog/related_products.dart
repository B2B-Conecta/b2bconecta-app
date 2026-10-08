import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

/// Hasta [limit] repuestos de la misma categoría.
/// Primero el mismo importador, después otros mayoristas.
List<PartModel> pickRelatedProducts({
  required PartModel current,
  required List<PartModel> candidates,
  int limit = 8,
}) {
  final cap = limit < 1 ? 1 : limit;
  final sameOwner = <PartModel>[];
  final others = <PartModel>[];
  final owner = current.ownerId?.trim();
  for (final part in candidates) {
    if (part.id == current.id || part.id.isEmpty) continue;
    if (!part.isActive || !part.stockCoversMinOrder) continue;
    final partOwner = part.ownerId?.trim();
    if (owner != null && owner.isNotEmpty && partOwner == owner) {
      sameOwner.add(part);
    } else {
      others.add(part);
    }
  }
  return [...sameOwner, ...others].take(cap).toList(growable: false);
}

String relatedProductsTitle(PartModel part) {
  final category = part.category?.trim();
  if (category == null || category.isEmpty) return 'Más de este proveedor';
  return 'Más en ${formatCatalogCategoryLabel(category).toLowerCase()}';
}
