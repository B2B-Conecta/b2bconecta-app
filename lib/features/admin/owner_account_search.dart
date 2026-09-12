import 'package:motolink_pro_app/features/profile/profile_model.dart';

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
