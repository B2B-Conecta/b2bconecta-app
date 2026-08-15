/// Valores de `transaction_requests.document_type_preference` (A6).
abstract final class DocumentTypePreference {
  static const notaEntrega = 'nota_entrega';
  static const facturaFiscal = 'factura_fiscal';

  static const Set<String> values = {notaEntrega, facturaFiscal};

  static String? labelEs(String? v) {
    final t = v?.trim();
    if (t == null || t.isEmpty) return null;
    switch (t) {
      case notaEntrega:
        return 'Nota de entrega simple';
      case facturaFiscal:
        return 'Factura fiscal';
      default:
        return t;
    }
  }
}
