import '../models/part_model.dart';

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
