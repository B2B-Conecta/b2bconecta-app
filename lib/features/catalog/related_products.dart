import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

/// Título fijo del carrusel de relacionados (detalle de producto).
const kRelatedProductsSectionTitle =
    'Productos relacionados que podrían interesarte';

/// Hasta [limit] repuestos de la misma categoría (fallback local sin RPC).
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

/// Conserva el orden de [orderedIds] al hidratar filas del catálogo.
List<PartModel> orderPartsByIds({
  required List<String> orderedIds,
  required List<PartModel> parts,
  int? limit,
}) {
  if (orderedIds.isEmpty || parts.isEmpty) return const [];
  final byId = <String, PartModel>{
    for (final part in parts)
      if (part.id.isNotEmpty) part.id: part,
  };
  final out = <PartModel>[];
  for (final id in orderedIds) {
    final part = byId[id];
    if (part == null) continue;
    out.add(part);
    if (limit != null && out.length >= limit) break;
  }
  return List<PartModel>.unmodifiable(out);
}

String relatedProductsTitle(PartModel part) {
  final category = part.category?.trim();
  if (category == null || category.isEmpty) return 'Más de este proveedor';
  return 'Más en ${formatCatalogCategoryLabel(category).toLowerCase()}';
}
