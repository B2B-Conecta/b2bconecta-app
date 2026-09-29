import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_filter_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

TransactionRequestModel _row(String status) {
  return TransactionRequestModel(
    id: status,
    aliadoId: 'a',
    productId: 'p',
    ownerId: 'o',
    status: status,
    cantidad: 1,
    precioUnitarioProveedor: 1,
    precioUnitarioAliado: 1,
    precioTotal: 1,
    precioBaseAliadoTotal: 1,
  );
}

void main() {
  test('filter chips collapse legado enviado into En tránsito', () {
    final chips = TransactionRequestStatus.distinctFilterStatuses(
      TransactionRequestStatus.motoconectaAdminOperationalActive,
    );
    expect(chips.where((s) => s == TransactionRequestStatus.enTransito), hasLength(1));
    expect(chips, isNot(contains(TransactionRequestStatus.enviado)));
    expect(
      chips.map(TransactionRequestStatus.labelEs).where((l) => l == 'En tránsito'),
      hasLength(1),
    );
  });

  test('En tránsito filter includes both en_transito and legado enviado', () {
    final rows = [
      _row(TransactionRequestStatus.enTransito),
      _row(TransactionRequestStatus.enviado),
      _row(TransactionRequestStatus.enPreparacion),
    ];
    final filtered = TransactionRequestFilterUtils.apply(
      rows,
      searchQuery: '',
      statusFilter: TransactionRequestStatus.enTransito,
    );
    expect(filtered.map((r) => r.status), [
      TransactionRequestStatus.enTransito,
      TransactionRequestStatus.enviado,
    ]);
  });
}
