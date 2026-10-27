/// Cantidad mínima de pedido (MOQ) por SKU.
///
/// Si el proveedor no indica un mínimo, se usa [platformDefault] (5).
/// Si lo define, ese valor manda, con piso absoluto [absoluteFloor] (1).
abstract final class ProductMinOrderQty {
  /// Valor por defecto cuando el proveedor no define MOQ.
  static const platformDefault = 5;

  /// Alias histórico de [platformDefault].
  static const platformFloor = platformDefault;

  /// Unidades mínimas permitidas cuando el proveedor sí define MOQ.
  static const absoluteFloor = 1;

  static int resolve(int? raw) {
    if (raw == null || raw < absoluteFloor) return platformDefault;
    return raw;
  }

  static int? tryParse(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  static bool stockCovers({required int stock, required int? minOrderQty}) {
    return stock >= resolve(minOrderQty);
  }
}
