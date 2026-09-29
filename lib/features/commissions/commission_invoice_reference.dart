/// Referencia de factura/nota de comisión: formato canónico y compatibilidad ML-/B2B-.
abstract final class CommissionInvoiceReference {
  CommissionInvoiceReference._();

  static const brandPrefix = 'B2B';
  static const legacyBrandPrefix = 'ML';
  static const kindCom = 'COM';
  static const kindNot = 'NOT';
  static const seqWidth = 6;

  static const currentInvoicePrefix = '$brandPrefix-$kindCom-';
  static const currentNotePrefix = '$brandPrefix-$kindNot-';
  static const legacyInvoicePrefix = '$legacyBrandPrefix-$kindCom-';
  static const legacyNotePrefix = '$legacyBrandPrefix-$kindNot-';

  static final RegExp _fullPattern = RegExp(
    r'^(ML|B2B)-(COM|NOT)-(\d{4})-(\d{6})$',
  );

  static String format({
    required String kind,
    required int year,
    required int seq,
  }) {
    final k = kind.trim().toUpperCase();
    if (k != kindCom && k != kindNot) {
      throw ArgumentError.value(kind, 'kind', 'Use COM o NOT.');
    }
    if (year < 1000 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'Año de 4 dígitos.');
    }
    if (seq < 1 || seq > 999999) {
      throw ArgumentError.value(seq, 'seq', 'Secuencia 1–999999.');
    }
    return '$brandPrefix-$k-$year-${seq.toString().padLeft(seqWidth, '0')}';
  }

  static bool isValidPersisted(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return false;
    return _fullPattern.hasMatch(v);
  }

  static bool isNewFormat(String? raw) {
    final v = raw?.trim() ?? '';
    return v.startsWith('$brandPrefix-') && _fullPattern.hasMatch(v);
  }

  static bool isLegacyFormat(String? raw) {
    final v = raw?.trim() ?? '';
    return v.startsWith('$legacyBrandPrefix-') && _fullPattern.hasMatch(v);
  }

  /// Variante con el otro prefijo de marca (ML ↔ B2B), misma serie y correlativo.
  static String? swappedBrand(String? raw) {
    final v = raw?.trim() ?? '';
    final m = _fullPattern.firstMatch(v);
    if (m == null) return null;
    final brand = m.group(1)!;
    final rest = v.substring(brand.length);
    if (brand == brandPrefix) return '$legacyBrandPrefix$rest';
    return '$brandPrefix$rest';
  }

  static bool matchesQuery(String? stored, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final v = stored?.trim() ?? '';
    if (v.isEmpty) return false;
    if (v.toLowerCase().contains(q)) return true;
    final alias = swappedBrand(v);
    if (alias != null && alias.toLowerCase().contains(q)) return true;
    return false;
  }
}
