import 'package:motolink_pro_app/features/catalog/part_model.dart';

enum OwnerCatalogVisibility { todos, publicados, pausados }

/// Filtro local del catálogo owner (nombre, SKU, categoría y visibilidad).
List<PartModel> ownerCatalogFilter({
  required List<PartModel> items,
  required String rawQuery,
  required OwnerCatalogVisibility visibility,
}) {
  final q = rawQuery.trim().toLowerCase();
  return items.where((p) {
    switch (visibility) {
      case OwnerCatalogVisibility.publicados:
        if (!p.isActive) return false;
      case OwnerCatalogVisibility.pausados:
        if (p.isActive) return false;
      case OwnerCatalogVisibility.todos:
        break;
    }
    if (q.isEmpty) return true;
    bool hit(String? v) => (v ?? '').toLowerCase().contains(q);
    return hit(p.nombre) || hit(p.sku) || hit(p.category);
  }).toList();
}
