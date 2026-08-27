
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/jwt_clock_skew.dart';
import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/referrals/referrals_service.dart';
import 'package:motolink_pro_app/features/referrals/referral_invite_storage.dart';
import 'package:motolink_pro_app/features/ads/ad_attribution_storage.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

class ProfileService {
  ProfileService._();

  static RealtimeChannel subscribeToMyProfileAccess({
    required void Function() onAccessActive,
  }) {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) {
      throw StateError('No hay sesión activa para escuchar el perfil.');
    }
    final channel = SupabaseAccess.client.channel('profiles:access:$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: uid,
      ),
      callback: (payload) {
        final status =
            payload.newRecord['account_access_status']?.toString().trim();
        if (status == 'active') onAccessActive();
      },
    );
    channel.subscribe();
    return channel;
  }

  /// Perfil del usuario autenticado (`id` = `auth.uid()`). `null` si no hay fila.
  static Future<ProfileModel?> fetchMyProfile() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return null;

    return retryOnJwtIssuedAtFuture(() async {
      final data = await SupabaseAccess.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (data == null) return null;
      return ProfileModel.fromJson(Map<String, dynamic>.from(data));
    });
  }

  /// Nombre de negocio para mostrar en etiquetas de pedido.
  static Future<String?> fetchProfileBusinessName(String profileId) async {
    final id = profileId.trim();
    if (id.isEmpty) return null;
    final row = await SupabaseAccess.client
        .from('profiles')
        .select('business_name')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final n = row['business_name']?.toString().trim();
    if (n == null || n.isEmpty) return null;
    return n;
  }

  /// Perfil B2B por id (rutas automáticas, etiquetas).
  static Future<ProfileModel?> fetchProfileById(String profileId) async {
    final id = profileId.trim();
    if (id.isEmpty) return null;
    final row = await SupabaseAccess.client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ProfileModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Persiste GPS o geocodificación del domicilio fiscal (`profiles.latitude/longitude`).
  static Future<void> updateMyGeolocation({
    required double latitude,
    required double longitude,
  }) async {
    await SupabaseAccess.client.rpc(
      'update_my_geolocation',
      params: <String, dynamic>{
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
  }

  static String? _normalizeB2bRole(String? role) {
    final r = role?.trim().toLowerCase();
    if (r == 'importador' || r == 'aliado' || r == 'administrador') {
      return r;
    }
    return null;
  }

  /// Corrige enlaces pegados sin esquema (`://maps...` o `maps.app.goo.gl/...`).
  static String? normalizeHttpUrl(String? raw) {
    var t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.startsWith('://')) {
      t = 'https$t';
    } else if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(t)) {
      t = 'https://$t';
    }
    final u = Uri.tryParse(t);
    if (u == null ||
        !u.hasScheme ||
        (u.scheme != 'http' && u.scheme != 'https')) {
      return null;
    }
    return t;
  }

  /// Crea o actualiza el perfil B2B.
  ///
  /// El campo [role] solo se persiste en el primer alta o si el perfil aún no
  /// tiene rol válido en BD. Tras la primera asignación, los updates omiten
  /// `role` para que no pueda cambiarse desde el cliente.
  static Future<void> upsertMyProfile({
    required String businessName,
    required String rif,
    required String role,
    String? phone,
    String? estado,
    String? ciudad,
    String? direccion,
    String? fiscalMapsUrl,
    String? legalContactName,
    String? legalContactEmail,
    String? legalContactPhone,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) {
      throw StateError('No hay sesión activa.');
    }

    final requestedRole = _normalizeB2bRole(role);
    if (requestedRole == null) {
      throw ArgumentError(
        'Seleccione un rol válido (importador o aliado) antes de guardar.',
      );
    }

    final existing = await fetchMyProfile();

    final payload = <String, dynamic>{
      'business_name': businessName.trim(),
      'rif': rif.trim(),
    };

    final p = phone?.trim();
    if (p != null && p.isNotEmpty) {
      payload['phone'] = p;
    }

    final es = estado?.trim();
    payload['estado'] = (es == null || es.isEmpty) ? null : es;
    final ci = ciudad?.trim();
    payload['ciudad'] = (ci == null || ci.isEmpty) ? null : ci;
    final dir = direccion?.trim();
    payload['direccion'] = (dir == null || dir.isEmpty) ? null : dir;

    if (requestedRole == 'importador') {
      final ln = legalContactName?.trim();
      final le = legalContactEmail?.trim();
      final lp = legalContactPhone?.trim();
      payload['legal_contact_name'] = (ln == null || ln.isEmpty) ? null : ln;
      payload['legal_contact_email'] = (le == null || le.isEmpty) ? null : le;
      payload['legal_contact_phone'] = (lp == null || lp.isEmpty) ? null : lp;
    }

    final fmu = normalizeHttpUrl(fiscalMapsUrl);
    if (fmu != null) {
      payload['fiscal_maps_url'] = fmu;
    } else if (fiscalMapsUrl?.trim().isNotEmpty == true) {
      throw ArgumentError(
        'El enlace de Google Maps debe ser una URL http o https.',
      );
    } else {
      payload['fiscal_maps_url'] = null;
    }

    // PostgREST upsert sin `role` en el cuerpo puede dejar `role` en null (23502).
    // Insert incluye rol; update omite rol para no permitir cambiarlo desde el cliente.
    if (existing == null) {
      final attribution = await AdAttributionStorage.peek();
      await SupabaseAccess.client.from('profiles').insert({
        'id': uid,
        ...payload,
        'role': requestedRole,
        if (attribution != null && !attribution.isEmpty)
          ...attribution.toProfileColumns(),
      });
      await AdAttributionStorage.clear();
      final pendingReferral = await ReferralInviteStorage.consumePendingCode();
      if (pendingReferral != null && pendingReferral.isNotEmpty) {
        try {
          await ReferralsService.applyReferralCode(pendingReferral);
        } catch (_) {
          // Código inválido o ya aplicado vía metadata de Auth: no bloquear el alta.
        }
      }
    } else {
      await SupabaseAccess.client
          .from('profiles')
          .update(payload)
          .eq('id', uid);
    }
  }

  /// Mensaje legible para errores al guardar `profiles` (sin detalles Postgres).
  static String profileSaveErrorMessage(Object error) {
    if (error is ArgumentError) {
      final m = error.message?.toString().trim();
      if (m != null && m.isNotEmpty) return m;
      return 'Revise los datos del perfil e intente de nuevo.';
    }
    if (error is StateError) {
      final m = error.message.trim();
      if (m.isNotEmpty) return m;
    }
    if (error is PostgrestException) {
      final code = error.code?.trim();
      final msg = error.message.toLowerCase();
      if (code == '23505' && msg.contains('rif')) {
        return 'Ese RIF ya está registrado en B2B Conecta. Use el RIF fiscal real de su negocio.';
      }
      if (code == '23502' && msg.contains('role')) {
        return 'No se pudo guardar el perfil. Vuelva a seleccionar Importador o Aliado e intente de nuevo.';
      }
    }
    return 'No se pudo guardar el perfil. Revise los datos e intente de nuevo.';
  }

  static Future<String> createSignedUrlForProfileLogo(
      String storagePath) async {
    final p = storagePath.trim();
    if (p.isEmpty) {
      throw ArgumentError('Ruta de logo vacía.');
    }
    return SupabaseAccess.client.storage
        .from(SupabaseAccess.profileLogosBucket)
        .createSignedUrl(p, 3600);
  }

  /// Sube o reemplaza el logo del perfil y actualiza `profiles.logo_storage_path`.
  static Future<void> uploadMyProfileLogo({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final ext = fileExtension.trim().toLowerCase().replaceAll('.', '');
    if (ext != 'png' && ext != 'jpg' && ext != 'jpeg' && ext != 'webp') {
      throw ArgumentError('Use PNG, JPG o WEBP.');
    }

    final prof = await fetchMyProfile();
    final oldPath = prof?.logoStoragePath?.trim();

    final path = '$uid/logo_${DateTime.now().microsecondsSinceEpoch}.$ext';
    final ct = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.profileLogosBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: ct, upsert: true),
        );

    await SupabaseAccess.client.from('profiles').update({
      'logo_storage_path': path,
    }).eq('id', uid);

    if (oldPath != null && oldPath.isNotEmpty && oldPath != path) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.profileLogosBucket)
            .remove([oldPath]);
      } catch (_) {}
    }
  }

  /// Quita el logo personalizado (vuelve al marcador por defecto en la app).
  static Future<void> clearMyProfileLogo() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final prof = await fetchMyProfile();
    final oldPath = prof?.logoStoragePath?.trim();
    await SupabaseAccess.client.from('profiles').update({
      'logo_storage_path': null,
    }).eq('id', uid);
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.profileLogosBucket)
            .remove([oldPath]);
      } catch (_) {}
    }
  }

  /// Importadores (`role = importador`) para el filtro del catálogo.
  static Future<void> acceptTerms({required String version}) async {
    await SupabaseAccess.client.rpc(
      'profile_accept_terms',
      params: <String, dynamic>{'p_version': version.trim()},
    );
  }
}
