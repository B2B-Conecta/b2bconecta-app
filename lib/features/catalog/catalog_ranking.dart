import 'part_model.dart';
import 'catalog_sort_mode.dart';

int _compareCatalogFeatured(PartModel a, PartModel b) {
  final fa = a.isCatalogFeatured ? 1 : 0;
  final fb = b.isCatalogFeatured ? 1 : 0;
  return fb.compareTo(fa);
}

/// Orden de catálogo aliado: destacado admin, luego boost por pagos, luego reputación.
int comparePartsForCatalogBoost(PartModel a, PartModel b) {
  final featured = _compareCatalogFeatured(a, b);
  if (featured != 0) return featured;
  final pa = a.ownerCatalogPaidOrders30d ?? 0;
  final pb = b.ownerCatalogPaidOrders30d ?? 0;
  final cPaid = pb.compareTo(pa);
  if (cPaid != 0) return cPaid;

  final ra = a.ownerRatingAvg;
  final rb = b.ownerRatingAvg;
  if (ra != null && rb != null) {
    final cRating = rb.compareTo(ra);
    if (cRating != 0) return cRating;
  } else if (ra != null) {
    return -1;
  } else if (rb != null) {
    return 1;
  }

  return a.id.compareTo(b.id);
}

String _categorySortKey(PartModel p) => (p.category ?? '').trim().toLowerCase();

String _nameSortKey(PartModel p) => p.nombre.trim().toLowerCase();

/// Categoría A–Z (vacías al final), luego nombre A–Z.
int comparePartsByCategoryThenName(PartModel a, PartModel b) {
  final ca = _categorySortKey(a);
  final cb = _categorySortKey(b);
  if (ca.isEmpty && cb.isNotEmpty) return 1;
  if (cb.isEmpty && ca.isNotEmpty) return -1;
  final byCat = ca.compareTo(cb);
  if (byCat != 0) return byCat;
  final byName = _nameSortKey(a).compareTo(_nameSortKey(b));
  if (byName != 0) return byName;
  return a.id.compareTo(b.id);
}

int comparePartsForSortMode(PartModel a, PartModel b, CatalogSortMode mode) {
  switch (mode) {
    case CatalogSortMode.category:
      return comparePartsByCategoryThenName(a, b);
    case CatalogSortMode.featured:
      return comparePartsForCatalogFeatured(a, b);
    case CatalogSortMode.recommended:
    case CatalogSortMode.nearest:
      return comparePartsForCatalogBoost(a, b);
  }
}

/// Orden: Destacados primero, luego reputación y ventas.
int comparePartsForCatalogFeatured(PartModel a, PartModel b) {
  final featured = _compareCatalogFeatured(a, b);
  if (featured != 0) return featured;
  final ra = a.ownerRatingAvg;
  final rb = b.ownerRatingAvg;
  if (ra != null && rb != null) {
    final cRating = rb.compareTo(ra);
    if (cRating != 0) return cRating;
  } else if (ra != null) {
    return -1;
  } else if (rb != null) {
    return 1;
  }

  final pa = a.ownerCatalogPaidOrders30d ?? 0;
  final pb = b.ownerCatalogPaidOrders30d ?? 0;
  final cPaid = pb.compareTo(pa);
  if (cPaid != 0) return cPaid;

  return a.id.compareTo(b.id);
}

/// Desempate por distancia (misma distancia → boost/reputación recomendado).
int comparePartsByDistanceThenCatalogBoost(PartModel a, PartModel b) {
  final da = a.distanceKmFromReference;
  final db = b.distanceKmFromReference;
  if (da == null && db == null) return comparePartsForCatalogBoost(a, b);
  if (da == null) return 1;
  if (db == null) return -1;
  final c = da.compareTo(db);
  if (c != 0) return c;
  return comparePartsForCatalogBoost(a, b);
}
