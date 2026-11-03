import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

void main() {
  TransactionRequestModel line({
    double? tasa,
    DateTime? recalcAt,
    double? totalBs,
  }) {
    return TransactionRequestModel.fromJson({
      'id': '11111111-2222-3333-4444-555555555555',
      'aliado_id': '11111111-2222-3333-4444-555555555501',
      'importador_id': '11111111-2222-3333-4444-555555555502',
      'product_id': '11111111-2222-3333-4444-555555555503',
      'status': 'confirmado',
      'cantidad': 1,
      'precio_total_usd': 49.95,
      'tasa_bcv_aplicada': tasa,
      'tasa_bcv_recalc_at': recalcAt?.toIso8601String(),
      'total_bs': totalBs,
      'metodo_pago_moneda': 'BOLIVARES',
    });
  }

  test('detecta tasa desactualizada y disponibilidad de un solo uso', () {
    final stale = line(tasa: 889.17, totalBs: 44434.29);
    expect(stale.tasaBcvDesactualizadaRespecto(900.0), isTrue);
    expect(stale.tasaBcvDesactualizadaRespecto(889.17), isFalse);
    expect(stale.tasaBcvRecalcDisponible, isTrue);

    final used = line(
      tasa: 889.17,
      totalBs: 44434.29,
      recalcAt: DateTime.utc(2026, 11, 3),
    );
    expect(used.tasaBcvRecalcDisponible, isFalse);
  });
}
