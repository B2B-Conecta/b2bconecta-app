/// Tipo de documento al emitir un corte de comisión (E3).
enum CommissionSettlementDocumentType {
  fiscalInvoice('fiscal_invoice'),
  deliveryNote('delivery_note');

  const CommissionSettlementDocumentType(this.rpcValue);

  final String rpcValue;

  static CommissionSettlementDocumentType? fromStored(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    for (final d in CommissionSettlementDocumentType.values) {
      if (d.rpcValue == v) return d;
    }
    return null;
  }

  /// Cortes legacy emitidos antes de E3 se tratan como factura fiscal.
  static CommissionSettlementDocumentType effective(String? raw) =>
      fromStored(raw) ?? CommissionSettlementDocumentType.fiscalInvoice;

  /// Etiqueta en listados del panel admin.
  String get labelEs {
    switch (this) {
      case CommissionSettlementDocumentType.fiscalInvoice:
        return 'Factura fiscal';
      case CommissionSettlementDocumentType.deliveryNote:
        return 'ML-NOT';
    }
  }

  /// Etiqueta para el importador (documento que recibe).
  String get importerDocumentLabelEs {
    switch (this) {
      case CommissionSettlementDocumentType.fiscalInvoice:
        return 'Factura fiscal';
      case CommissionSettlementDocumentType.deliveryNote:
        return 'Nota de entrega';
    }
  }

  /// Acción discreta en panel admin.
  String get adminEmitActionLabel {
    switch (this) {
      case CommissionSettlementDocumentType.fiscalInvoice:
        return 'Emitir factura';
      case CommissionSettlementDocumentType.deliveryNote:
        return 'ML-NOT';
    }
  }

  String get referencePrefix {
    switch (this) {
      case CommissionSettlementDocumentType.fiscalInvoice:
        return 'ML-COM-';
      case CommissionSettlementDocumentType.deliveryNote:
        return 'ML-NOT-';
    }
  }
}
