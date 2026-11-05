import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Orden del listado de cuentas en administración.
enum OwnerAccountSort {
  newest,
  oldest,
  name,
}

extension OwnerAccountSortLabel on OwnerAccountSort {
  String get labelEs => switch (this) {
        OwnerAccountSort.newest => 'Más recientes',
        OwnerAccountSort.oldest => 'Más antiguas',
        OwnerAccountSort.name => 'Nombre',
      };
}

/// Búsqueda de ficha owner: empresa, RIF, correo, teléfono y domicilio.
bool ownerAccountMatchesQuery(ProfileModel profile, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  bool hit(String? v) => (v ?? '').toLowerCase().contains(q);
  return hit(profile.businessName) ||
      hit(profile.rif) ||
      hit(profile.email) ||
      hit(profile.phone) ||
      hit(profile.legalContactName) ||
      hit(profile.legalContactEmail) ||
      hit(profile.legalContactPhone) ||
      hit(profile.estado) ||
      hit(profile.ciudad) ||
      hit(profile.direccion);
}

/// Ordena cuentas por fecha de alta o nombre (estable para nulos).
List<ProfileModel> sortOwnerAccounts(
  Iterable<ProfileModel> rows, {
  required OwnerAccountSort sort,
}) {
  final list = rows.toList(growable: true);
  int byName(ProfileModel a, ProfileModel b) {
    final an = (a.businessName?.trim().isNotEmpty == true
            ? a.businessName!.trim()
            : (a.email ?? a.id))
        .toLowerCase();
    final bn = (b.businessName?.trim().isNotEmpty == true
            ? b.businessName!.trim()
            : (b.email ?? b.id))
        .toLowerCase();
    final cmp = an.compareTo(bn);
    if (cmp != 0) return cmp;
    return a.id.compareTo(b.id);
  }

  int byCreated(ProfileModel a, ProfileModel b, {required bool newestFirst}) {
    final aAt = a.createdAt;
    final bAt = b.createdAt;
    if (aAt == null && bAt == null) return byName(a, b);
    if (aAt == null) return 1;
    if (bAt == null) return -1;
    final cmp = aAt.compareTo(bAt);
    if (cmp != 0) return newestFirst ? -cmp : cmp;
    return byName(a, b);
  }

  list.sort((a, b) {
    switch (sort) {
      case OwnerAccountSort.newest:
        return byCreated(a, b, newestFirst: true);
      case OwnerAccountSort.oldest:
        return byCreated(a, b, newestFirst: false);
      case OwnerAccountSort.name:
        return byName(a, b);
    }
  });
  return list;
}

/// Ordena registros incompletos por fecha de creación.
List<T> sortByCreatedAt<T>(
  Iterable<T> rows, {
  required DateTime? Function(T row) createdAtOf,
  required String Function(T row) tieBreakKey,
  bool newestFirst = true,
}) {
  final list = rows.toList(growable: true);
  list.sort((a, b) {
    final aAt = createdAtOf(a);
    final bAt = createdAtOf(b);
    if (aAt == null && bAt == null) {
      return tieBreakKey(a).compareTo(tieBreakKey(b));
    }
    if (aAt == null) return 1;
    if (bAt == null) return -1;
    final cmp = aAt.compareTo(bAt);
    if (cmp != 0) return newestFirst ? -cmp : cmp;
    return tieBreakKey(a).compareTo(tieBreakKey(b));
  });
  return list;
}
