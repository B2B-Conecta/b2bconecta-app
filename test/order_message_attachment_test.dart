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
}
