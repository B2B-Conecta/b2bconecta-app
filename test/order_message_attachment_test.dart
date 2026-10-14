import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/order_message_attachment.dart';
import 'package:motolink_pro_app/features/orders/shared/order_return_rules.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_message_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

void main() {
  test('un mensaje de texto viejo no exige adjuntos', () {
    final message = TransactionRequestMessageModel.fromJson({
      'id': 'm1',
      'transaction_request_id': 'o1',
      'author_id': 'u1',
      'author_role': 'aliado',
      'body': 'Hola',
      'created_at': '2026-10-01T12:00:00Z',
    });
    expect(message.body, 'Hola');
    expect(message.attachments, isEmpty);
  });

  test('lee foto y descarta un adjunto mal formado', () {
    final message = TransactionRequestMessageModel.fromJson({
      'id': 'm2',
      'transaction_request_id': 'o1',
      'author_id': 'u2',
      'author_role': 'importador',
      'body': '',
      'attachments': [
        {
          'path': 'o1/m2/foto.jpeg',
          'kind': 'image',
          'mime': 'image/jpeg',
          'name': 'foto.jpeg',
        },
        {'kind': 'video'},
        {'path': '../secreto', 'kind': 'image'},
      ],
    });
    expect(message.attachments, hasLength(1));
    expect(message.attachments.single.isImage, isTrue);
    expect(message.attachments.single.path, 'o1/m2/foto.jpeg');
  });

  test('devolución solo en entregado y dentro de 7 días', () {
    final deliveredAt = DateTime.utc(2026, 10, 1, 15);
    expect(
      OrderReturnRules.isAvailable(
        status: TransactionRequestStatus.entregado,
        updatedAt: deliveredAt,
        now: DateTime.utc(2026, 10, 8, 15),
      ),
      isTrue,
    );
    expect(
      OrderReturnRules.isAvailable(
        status: TransactionRequestStatus.entregado,
        updatedAt: deliveredAt,
        now: DateTime.utc(2026, 10, 8, 15, 0, 1),
      ),
      isFalse,
    );
    expect(
      OrderReturnRules.isAvailable(
        status: TransactionRequestStatus.enPreparacion,
        updatedAt: deliveredAt,
        now: deliveredAt,
      ),
      isFalse,
    );
    expect(
      OrderReturnRules.isAvailable(
        status: TransactionRequestStatus.rechazado,
        updatedAt: deliveredAt,
        now: deliveredAt,
      ),
      isFalse,
    );
    expect(
      OrderReturnRules.isAvailable(
        status: TransactionRequestStatus.entregado,
        updatedAt: null,
        now: deliveredAt,
      ),
      isFalse,
    );
  });

  test('el plazo de postventa usa la fecha de entrega', () {
    final delivered = DateTime.utc(2026, 10, 1, 12);
    final laterEdit = DateTime.utc(2026, 10, 20, 12);
    expect(
      OrderReturnRules.isAvailable(
        status: TransactionRequestStatus.entregado,
        deliveredAt: delivered,
        updatedAt: laterEdit,
        now: DateTime.utc(2026, 10, 8, 12),
      ),
      isTrue,
    );
    expect(
      OrderReturnRules.isAvailable(
        status: TransactionRequestStatus.entregado,
        deliveredAt: delivered,
        updatedAt: laterEdit,
        now: DateTime.utc(2026, 10, 9, 12),
      ),
      isFalse,
    );
  });

  test('la recepción confirma el plazo de 7 días', () {
    expect(OrderReturnRules.receptionConfirmedHint, contains('7 días'));
    expect(
      OrderReturnRules.receptionConfirmedPagoPendienteHint,
      contains('7 días'),
    );
  });

  test('las unidades afectadas no superan la línea y el crédito usa el precio', () {
    expect(OrderReturnRules.clampAffectedQty(0, 4), 1);
    expect(OrderReturnRules.clampAffectedQty(9, 4), 4);
    expect(
      OrderReturnRules.creditAmount(
        unitPrice: 12.5,
        lineTotal: 50,
        lineQty: 4,
        affectedQty: 2,
      ),
      25,
    );
    expect(
      OrderReturnRules.creditAmount(
        unitPrice: 0,
        lineTotal: 40,
        lineQty: 4,
        affectedQty: 1,
      ),
      10,
    );
  });

  test('el saldo a favor no supera el subtotal del proveedor', () {
    expect(OrderReturnRules.cappedCredit(30, 12.5), 12.5);
    expect(OrderReturnRules.cappedCredit(8, 20), 8);
    expect(OrderReturnRules.cappedCredit(0, 20), 0);
    expect(OrderReturnRules.preferenceLabel('credito'), 'Crédito a favor');
    expect(
      OrderReturnRules.replacementStatusLabel('pendiente_retiro'),
      'Pendiente por retiro',
    );
  });

  test('el chat reconoce la tarjeta de la solicitud', () {
    final parsed = OrderReturnRules.parseReturnRequestMessage(
      'Solicitud de devolución. Preferencia: cambio de producto. Producto: Disco freno delantero 245 mm. Unidades: 2. Llegó rayado.',
    );
    expect(parsed, isNotNull);
    expect(parsed!.preference, 'cambio');
    expect(parsed.productName, 'Disco freno delantero 245 mm');
    expect(parsed.units, 2);
    expect(parsed.reason, 'Llegó rayado.');
    expect(
      OrderReturnRules.parseReturnRequestMessage('Hola, ¿llegó el pedido?'),
      isNull,
    );
  });
}
