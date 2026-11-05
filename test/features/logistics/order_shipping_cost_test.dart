import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

void main() {
  TransactionRequestModel order({
    bool? shippingIncluded,
    double? shippingCostUsd,
    double? shippingCostBs,
    double precioTotal = 100,
    double? totalRef,
    double? totalBs,
    double? tasaBcvAplicada,
  }) {
    return TransactionRequestModel(
      id: '1',
      aliadoId: 'a',
      productId: 'p',
      ownerId: 'o',
      status: 'pedido_listo',
      cantidad: 1,
      precioUnitarioProveedor: precioTotal,
      precioUnitarioAliado: precioTotal,
      precioTotal: precioTotal,
      precioBaseAliadoTotal: precioTotal,
      shippingIncluded: shippingIncluded,
      shippingCostUsd: shippingCostUsd,
      shippingCostBs: shippingCostBs,
      totalRef: totalRef,
      totalBs: totalBs,
      tasaBcvAplicada: tasaBcvAplicada,
    );
  }

  test('flete incluido no suma monto al total', () {
    final r = order(shippingIncluded: true, shippingCostUsd: 12);
    expect(r.shippingConfigured, isTrue);
    expect(r.hasExtraShippingCost, isFalse);
    expect(r.grandTotalUsd, 100);
    expect(r.shippingSummaryLabel, contains('incluido'));
  });

  test('flete adicional suma USD y Bs al total', () {
    final r = order(
      shippingIncluded: false,
      shippingCostUsd: 15,
      shippingCostBs: 1500,
      totalRef: 100,
      totalBs: 10000,
      tasaBcvAplicada: 100,
    );
    expect(r.hasExtraShippingCost, isTrue);
    expect(r.grandTotalUsd, 115);
    expect(r.grandTotalBs, 11500);
    expect(r.shippingSummaryLabel, contains('15.00 USD'));
  });
}
