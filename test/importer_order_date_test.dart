import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/models/transaction_request_model.dart';
import 'package:motolink_pro_app/models/transaction_request_status.dart';
import 'package:motolink_pro_app/utils/importer_order_date.dart';

TransactionRequestModel _row({
  required String status,
  DateTime? createdAt,
  DateTime? atEntregado,
  DateTime? atRechazado,
}) {
  return TransactionRequestModel(
    id: 'id-$status',
    aliadoId: 'a',
    productId: 'p',
    ownerId: 'o',
    status: status,
    cantidad: 1,
    precioUnitarioProveedor: 1,
    precioUnitarioAliado: 1,
    precioTotal: 1,
    precioBaseAliadoTotal: 1,
    createdAt: createdAt,
    atEntregado: atEntregado,
    atRechazado: atRechazado,
  );
}

void main() {
  test('pedido activo label', () {
    final r = _row(
      status: TransactionRequestStatus.pendiente,
      createdAt: DateTime(2026, 3, 1),
    );
    expect(ImporterOrderDate.etiquetaFecha(r), 'Pedido activo');
    expect(ImporterOrderDate.isAbierto(r), isTrue);
  });

  test('fecha cierre entregado', () {
    final cierre = DateTime.utc(2026, 5, 10, 14);
    final r = _row(
      status: TransactionRequestStatus.entregado,
      atEntregado: cierre,
    );
    expect(ImporterOrderDate.etiquetaFecha(r), '10/05/2026');
    expect(ImporterOrderDate.fechaCierre(r), cierre);
  });

  test('filtro usa cierre en cerrados y alta en activos', () {
    final activo = _row(
      status: TransactionRequestStatus.enPreparacion,
      createdAt: DateTime(2026, 6, 1),
    );
    final cerrado = _row(
      status: TransactionRequestStatus.entregado,
      createdAt: DateTime(2026, 1, 1),
      atEntregado: DateTime(2026, 6, 5),
    );
    expect(
      ImporterOrderDate.matchesDateRange(
        activo,
        dateFrom: DateTime(2026, 6, 1),
        dateTo: DateTime(2026, 6, 30),
      ),
      isTrue,
    );
    expect(
      ImporterOrderDate.matchesDateRange(
        cerrado,
        dateFrom: DateTime(2026, 6, 1),
        dateTo: DateTime(2026, 6, 30),
      ),
      isTrue,
    );
    expect(
      ImporterOrderDate.matchesDateRange(
        cerrado,
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 1, 31),
      ),
      isFalse,
    );
  });
}
