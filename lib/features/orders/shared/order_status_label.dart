import 'transaction_request_status.dart';

/// Short, consistent wording for order cards and list filters.
String orderStatusLabel(String status) => switch (status) {
      TransactionRequestStatus.pendiente => 'Por confirmar',
      TransactionRequestStatus.aprobadoAdmin ||
      TransactionRequestStatus.enPreparacion =>
        'Preparando',
      TransactionRequestStatus.pedidoListo => 'Listo para salir',
      TransactionRequestStatus.enTransito ||
      TransactionRequestStatus.enviado =>
        'En camino',
      TransactionRequestStatus.entregado => 'Entregado',
      TransactionRequestStatus.rechazado => 'Cancelado',
      _ => TransactionRequestStatus.labelEs(status),
    };
