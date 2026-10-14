import 'transaction_request_status.dart';

/// Plazo para registrar una devolución o una queja.
///
/// Solo con el pedido `entregado`, durante 7 días desde la entrega
/// (`at_entregado`). Si esa fecha no existe, se usa `updated_at`.
class ParsedReturnRequest {
  const ParsedReturnRequest({
    required this.preference,
    required this.preferenceLabel,
    required this.productName,
    required this.units,
    required this.reason,
  });

  final String preference;
  final String preferenceLabel;
  final String productName;
  final int units;
  final String reason;
}

abstract final class OrderReturnRules {
  static const window = Duration(days: 7);

  static const closedHint =
      'El plazo de 7 días para reportar un inconveniente terminó.';

  static const receptionConfirmedHint =
      'Recepción confirmada. El pedido queda registrado. Durante 7 días puede reportar un inconveniente con un producto.';

  static const receptionConfirmedPagoPendienteHint =
      'Recepción registrada. La mercancía queda como entregada. Durante 7 días puede reportar un inconveniente con un producto. El comprobante de pago sigue pendiente de registrar o aprobar por B2B Conecta.';

  static const openHint =
      'Si un producto tuvo un inconveniente, repórtelo dentro de los 7 días. Elija crédito o cambio y adjunte una foto o un video. El pedido sigue entregado.';

  static DateTime? anchor({
    DateTime? deliveredAt,
    DateTime? updatedAt,
  }) =>
      deliveredAt ?? updatedAt;

  static bool isAvailable({
    required String status,
    required DateTime? updatedAt,
    DateTime? deliveredAt,
    DateTime? now,
  }) {
    if (status != TransactionRequestStatus.entregado) return false;
    final at = anchor(deliveredAt: deliveredAt, updatedAt: updatedAt);
    if (at == null) return false;
    final clock = (now ?? DateTime.now()).toUtc();
    final start = at.toUtc();
    if (clock.isBefore(start)) return false;
    return clock.difference(start) <= window;
  }

  static DateTime? availableUntil({
    DateTime? deliveredAt,
    DateTime? updatedAt,
  }) {
    final at = anchor(deliveredAt: deliveredAt, updatedAt: updatedAt);
    if (at == null) return null;
    return at.toUtc().add(window);
  }

  /// Unidades del producto que presentaron el inconveniente, entre 1 y la línea.
  static int clampAffectedQty(int requested, int lineQty) {
    final maxQty = lineQty < 1 ? 1 : lineQty;
    if (requested < 1) return 1;
    if (requested > maxQty) return maxQty;
    return requested;
  }

  /// Crédito REF de las unidades afectadas. Usa el precio de la tienda.
  static double creditAmount({
    required double unitPrice,
    required double lineTotal,
    required int lineQty,
    required int affectedQty,
  }) {
    final qty = clampAffectedQty(affectedQty, lineQty);
    final unit = unitPrice > 0
        ? unitPrice
        : (lineQty > 0 ? lineTotal / lineQty : lineTotal);
    if (unit <= 0) return 0;
    return double.parse((unit * qty).toStringAsFixed(4));
  }

  /// Saldo que cabe en el subtotal de ese importador.
  static double cappedCredit(double available, double subtotal) {
    if (available <= 0 || subtotal <= 0) return 0;
    final value = available < subtotal ? available : subtotal;
    return double.parse(value.toStringAsFixed(4));
  }

  static String preferenceLabel(String? value) {
    switch (value) {
      case 'credito':
        return 'Crédito a favor';
      case 'cambio':
        return 'Cambio de producto';
      default:
        return '';
    }
  }

  /// Lee el mensaje que deja el registro de una devolución en el chat.
  static ParsedReturnRequest? parseReturnRequestMessage(String body) {
    final text = body.trim();
    const prefix = 'Solicitud de devolución. Preferencia: ';
    if (!text.startsWith(prefix)) return null;
    const productMark = '. Producto: ';
    const unitsMark = '. Unidades: ';
    final productAt = text.indexOf(productMark, prefix.length);
    if (productAt < 0) return null;
    final unitsAt = text.indexOf(unitsMark, productAt + productMark.length);
    if (unitsAt < 0) return null;
    final preferenceLabel = text.substring(prefix.length, productAt).trim();
    final productName =
        text.substring(productAt + productMark.length, unitsAt).trim();
    final afterUnits = text.substring(unitsAt + unitsMark.length);
    final dot = afterUnits.indexOf('.');
    final unitsRaw =
        (dot < 0 ? afterUnits : afterUnits.substring(0, dot)).trim();
    final reason = dot < 0 ? '' : afterUnits.substring(dot + 1).trim();
    final lower = preferenceLabel.toLowerCase();
    final preference = lower.contains('crédit') || lower.contains('credit')
        ? 'credito'
        : 'cambio';
    return ParsedReturnRequest(
      preference: preference,
      preferenceLabel: preferenceLabel,
      productName: productName,
      units: int.tryParse(unitsRaw) ?? 0,
      reason: reason,
    );
  }

  static String replacementStatusLabel(String? status) {
    switch (status) {
      case 'pendiente_retiro':
        return 'Pendiente por retiro';
      case 'en_transito':
        return 'En tránsito';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return '';
    }
  }
}
