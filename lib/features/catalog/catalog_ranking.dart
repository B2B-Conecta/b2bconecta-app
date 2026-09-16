import 'part_model.dart';
import 'catalog_sort_mode.dart';

/// Orden de catálogo aliado (E1.1 + E2.1): boost por pagos confirmados, luego reputación rolling 100.
int comparePartsForCatalogBoost(PartModel a, PartModel b) {
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
    case CatalogSortMode.reputation:
      return comparePartsForCatalogReputation(a, b);
    case CatalogSortMode.recommended:
    case CatalogSortMode.nearest:
      return comparePartsForCatalogBoost(a, b);
  }
}

/// Orden E2.2: reputación rolling primero, luego boost E1.1.
int comparePartsForCatalogReputation(PartModel a, PartModel b) {
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

/// Desempate por distancia (misma distancia → reputación primero).
int comparePartsByDistanceThenCatalogReputation(PartModel a, PartModel b) {
  final da = a.distanceKmFromReference;
  final db = b.distanceKmFromReference;
  if (da == null && db == null) return comparePartsForCatalogReputation(a, b);
  if (da == null) return 1;
  if (db == null) return -1;
  final c = da.compareTo(db);
  if (c != 0) return c;
  return comparePartsForCatalogReputation(a, b);
}
