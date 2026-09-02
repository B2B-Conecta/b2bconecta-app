/// Piso de plataforma y helpers de cantidad mínima de pedido (MOQ).
///
/// Cada importador define el mínimo por SKU. No se acepta menos de
/// [platformFloor] (acuerdo comercial: no se vende de a 1).
abstract final class ProductMinOrderQty {
  static const platformFloor = 5;

  static int resolve(int? raw) {
    if (raw == null || raw < platformFloor) return platformFloor;
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
