/// Tipos de documento KYC (`profile_documents.doc_type`).
///
/// Cada documento lógico admite hasta [maxPhotosPerDoc] archivos:
/// `base`, `base_2`, `base_3`.
abstract final class AliadoDocType {
  static const maxPhotosPerDoc = 3;

  static const fotoTienda = 'foto_tienda';
  static const fotoTienda2 = 'foto_tienda_2';
  static const fotoTienda3 = 'foto_tienda_3';

  static const registroMercantil = 'registro_mercantil';
  static const cedulaPropietario = 'cedula_propietario';

  /// Importador y legado aliado.
  static const cedulaRepresentante = 'cedula_representante';

  static const referenciaBancaria1 = 'referencia_bancaria_1';
  static const referenciaBancaria2 = 'referencia_bancaria_2';
  static const referenciaComercial = 'referencia_comercial';

  /// Solo archivos históricos (ya no se solicita en UI).
  static const actaConstitutiva = 'acta_constitutiva';

  /// Documento lógico «Fotografías del local».
  static const storePhotoBase = fotoTienda;

  /// Mínimos para ingresar y enviar a revisión inicial (slot 1).
  static const kycRequiredAliado = [
    fotoTienda,
    cedulaPropietario,
    registroMercantil,
  ];

  /// Complementarios: pueden subirse después de ingresar a la plataforma.
  static const kycSupplementaryAliado = [
    referenciaBancaria1,
    referenciaBancaria2,
    referenciaComercial,
  ];

  /// Grupos documentales admin (aliado), sin expandir slots.
  static const kycDocGroupsAliado = [
    cedulaPropietario,
    registroMercantil,
    ...kycSupplementaryAliado,
    storePhotoBase,
  ];

  /// Mayoristas no requieren expediente documental KYC (solo minoristas).
  static const kycDocGroupsImportador = <String>[];

  static const legacyTypes = [
    actaConstitutiva,
  ];

  /// Tipo base sin sufijo `_2` / `_3`.
  static String baseType(String type) {
    final t = type.trim();
    if (t.endsWith('_2') || t.endsWith('_3')) {
      return t.substring(0, t.length - 2);
    }
    return t;
  }

  /// Índice 1..3 del slot fotográfico.
  static int photoSlotIndex(String type) {
    final t = type.trim();
    if (t.endsWith('_2')) return 2;
    if (t.endsWith('_3')) return 3;
    return 1;
  }

  /// Los 3 `doc_type` de un documento lógico.
  static List<String> photoSlotsFor(String baseOrSlot) {
    final base = baseType(baseOrSlot);
    return [base, '${base}_2', '${base}_3'];
  }

  static bool isPhotoSlotOf(String type, String base) =>
      baseType(type) == baseType(base);

  static bool isStorePhoto(String type) => isPhotoSlotOf(type, storePhotoBase);

  static List<String> forRole(String role) {
    if (role.trim().toLowerCase() == 'importador') return const [];
    return List<String>.from(kycRequiredAliado);
  }

  static List<String> supplementaryForRole(String role) {
    if (role.trim().toLowerCase() == 'aliado') {
      return List<String>.from(kycSupplementaryAliado);
    }
    return const [];
  }

  /// Grupos lógicos (1 por documento) para UI de expediente.
  /// Solo minoristas (`aliado`); mayoristas no solicitan documentación KYC.
  static List<String> docGroupsForAdmin({
    required String? role,
    required Iterable<String> uploadedTypes,
  }) {
    final r = role?.trim().toLowerCase() ?? 'aliado';
    if (r == 'importador' || r == 'administrador') return const [];
    final out = <String>[...kycDocGroupsAliado];
    for (final raw in uploadedTypes) {
      final base = baseType(raw);
      if (!out.contains(base) &&
          (legacyTypes.contains(base) ||
              base == cedulaRepresentante ||
              base == cedulaPropietario ||
              base == storePhotoBase ||
              kycDocGroupsAliado.contains(base))) {
        out.add(base);
      }
    }
    return out;
  }

  /// Expandido a todos los slots (compat / listados planos).
  static List<String> forAdminReview({
    required String? role,
    required Iterable<String> uploadedTypes,
  }) {
    final groups = docGroupsForAdmin(role: role, uploadedTypes: uploadedTypes);
    final out = <String>[];
    for (final g in groups) {
      out.addAll(photoSlotsFor(g));
    }
    return out;
  }

  /// @Deprecated Use [docGroupsForAdmin] — se mantiene para callers que
  /// filtraban «legales sin tienda».
  static List<String> legalTypesForAdmin({
    required String? role,
    required Iterable<String> uploadedTypes,
  }) {
    return docGroupsForAdmin(role: role, uploadedTypes: uploadedTypes)
        .where((t) => !isStorePhoto(t))
        .toList();
  }

  static bool isLegacy(String type) => legacyTypes.contains(baseType(type));

  static bool isRequiredForInitialAliado(String type) =>
      kycRequiredAliado.contains(baseType(type)) ||
      kycRequiredAliado.contains(type.trim());

  static bool isSupplementaryAliado(String type) =>
      kycSupplementaryAliado.contains(baseType(type)) ||
      kycSupplementaryAliado.contains(type.trim());

  /// Cédula válida para aliado (clave nueva o legado).
  static bool isCedulaAliadoDoc(String type) {
    final t = baseType(type);
    return t == cedulaPropietario || t == cedulaRepresentante;
  }

  static String labelEs(String type) {
    final base = baseType(type);
    final slot = photoSlotIndex(type);
    final core = switch (base) {
      fotoTienda => 'Fotografías del local',
      registroMercantil => 'Registro mercantil / cámara',
      cedulaPropietario => 'Cédula del propietario',
      cedulaRepresentante => 'Cédula del representante legal',
      referenciaBancaria1 => 'Referencia bancaria (1)',
      referenciaBancaria2 => 'Referencia bancaria (2)',
      referenciaComercial => 'Referencia comercial / carta crédito',
      actaConstitutiva => 'Acta constitutiva / estatutos (histórico)',
      _ => base,
    };
    if (slot > 1 || type.trim().endsWith('_2') || type.trim().endsWith('_3')) {
      return '$core · foto $slot';
    }
    return core;
  }

  static String groupLabelEs(String baseOrSlot) => labelEs(baseType(baseOrSlot));

  static String labelEsCompact(String type) => labelEs(type);
}
