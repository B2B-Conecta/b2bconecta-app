/// Tipos de documento esperados para aliados (clave `profile_documents.doc_type`).
abstract final class AliadoDocType {
  static const actaConstitutiva = 'acta_constitutiva';
  static const registroMercantil = 'registro_mercantil';
  static const cedulaRepresentante = 'cedula_representante';
  static const referenciaBancaria1 = 'referencia_bancaria_1';
  static const referenciaBancaria2 = 'referencia_bancaria_2';
  static const referenciaComercial = 'referencia_comercial';

  static const List<String> all = [
    actaConstitutiva,
    registroMercantil,
    cedulaRepresentante,
    referenciaBancaria1,
    referenciaBancaria2,
    referenciaComercial,
  ];

  static String labelEs(String type) {
    switch (type) {
      case actaConstitutiva:
        return 'Acta constitutiva / estatutos';
      case registroMercantil:
        return 'Registro mercantil / cámara';
      case cedulaRepresentante:
        return 'Cédula del representante legal';
      case referenciaBancaria1:
        return 'Referencia bancaria (1)';
      case referenciaBancaria2:
        return 'Referencia bancaria (2)';
      case referenciaComercial:
        return 'Referencia comercial / carta crédito';
      default:
        return type;
    }
  }
}
