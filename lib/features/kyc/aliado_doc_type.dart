/// Tipos de documento KYC (`profile_documents.doc_type`).
abstract final class AliadoDocType {
  static const fotoTienda = 'foto_tienda';
  static const registroMercantil = 'registro_mercantil';
  static const cedulaPropietario = 'cedula_propietario';

  /// Importador y legado aliado.
  static const cedulaRepresentante = 'cedula_representante';

  static const referenciaBancaria1 = 'referencia_bancaria_1';
  static const referenciaBancaria2 = 'referencia_bancaria_2';
  static const referenciaComercial = 'referencia_comercial';

  /// Solo archivos históricos (ya no se solicita en UI).
  static const actaConstitutiva = 'acta_constitutiva';

  /// Mínimos para ingresar y enviar a revisión inicial.
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

  static const legacyTypes = [
    actaConstitutiva,
  ];

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

  /// Admin: requeridos + complementarios + legados ya subidos.
  static List<String> forAdminReview({
    required String? role,
    required Iterable<String> uploadedTypes,
  }) {
    final r = role?.trim().toLowerCase() ?? 'aliado';
    if (r == 'importador') return const [];
    final out = [
      ...kycRequiredAliado,
      ...kycSupplementaryAliado,
    ];
    for (final t in uploadedTypes) {
      if (!out.contains(t) &&
          (legacyTypes.contains(t) || t == cedulaRepresentante)) {
        out.add(t);
      }
    }
    return out;
  }

  static bool isLegacy(String type) => legacyTypes.contains(type.trim());

  static bool isRequiredForInitialAliado(String type) =>
      kycRequiredAliado.contains(type.trim());

  static bool isSupplementaryAliado(String type) =>
      kycSupplementaryAliado.contains(type.trim());

  /// Cédula válida para aliado (clave nueva o legado).
  static bool isCedulaAliadoDoc(String type) {
    final t = type.trim();
    return t == cedulaPropietario || t == cedulaRepresentante;
  }

  static String labelEs(String type) {
    switch (type.trim()) {
      case fotoTienda:
        return 'Foto de la tienda';
      case registroMercantil:
        return 'Registro mercantil / cámara';
      case cedulaPropietario:
        return 'Cédula del propietario';
      case cedulaRepresentante:
        return 'Cédula del representante legal';
      case referenciaBancaria1:
        return 'Referencia bancaria (1)';
      case referenciaBancaria2:
        return 'Referencia bancaria (2)';
      case referenciaComercial:
        return 'Referencia comercial / carta crédito';
      case actaConstitutiva:
        return 'Acta constitutiva / estatutos (histórico)';
      default:
        return type;
    }
  }

  static String labelEsCompact(String type) => labelEs(type);
}
