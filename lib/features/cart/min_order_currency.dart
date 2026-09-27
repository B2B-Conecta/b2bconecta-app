/// Unidad de presentación del pedido mínimo.
/// REF = precio de catálogo / carrito. Divisa = USD de pago (Zelle, USDT, Binance),
/// que puede ser menor que REF si hay descuento por pago en dólares.
/// El checkout sigue validando el subtotal REF.
enum MinOrderCurrency {
  ref,
  usd;

  static MinOrderCurrency parse(String? raw) {
    final t = raw?.trim().toLowerCase();
    if (t == 'usd' || t == 'divisa') return MinOrderCurrency.usd;
    return MinOrderCurrency.ref;
  }

  String get dbValue => this == MinOrderCurrency.usd ? 'usd' : 'ref';

  /// Etiqueta corta para montos (REF o USD).
  String get unitLabel => this == MinOrderCurrency.usd ? 'USD' : 'REF';

  String get pickerLabel => this == MinOrderCurrency.usd ? 'Divisa' : 'REF';
}

String formatMinOrderAmount(double amount, MinOrderCurrency currency) {
  final n = amount.truncateToDouble() == amount
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '$n ${currency.unitLabel}';
}
