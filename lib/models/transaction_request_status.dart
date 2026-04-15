/// Estados de `transaction_requests` (trazabilidad broker + importador).
abstract final class TransactionRequestStatus {
  static const pendiente = 'pendiente';
  static const aprobadoAdmin = 'aprobado_admin';
  static const rechazado = 'rechazado';
  static const enPreparacion = 'en_preparacion';
  static const enTransito = 'en_transito';
  static const entregado = 'entregado';

  /// Ciclo post-validación MotoLink (pestaña Pedidos del importador).
  static const List<String> importerPipeline = [
    aprobadoAdmin,
    enPreparacion,
    enTransito,
    entregado,
  ];

  /// Solo aprobados por MotoLink pendientes de la primera acción del importador (pestaña Validados).
  static const List<String> importerSoloValidadosAdmin = [
    aprobadoAdmin,
  ];

  /// Solo preparación y tránsito (legacy / filtros internos si hiciera falta).
  static const List<String> importerActiveFulfillment = [
    enPreparacion,
    enTransito,
  ];

  /// Aprobados por MotoLink y en fulfillment (pestaña Pedidos activos — admin).
  static const List<String> adminOperationalActive = [
    aprobadoAdmin,
    enPreparacion,
    enTransito,
  ];

  /// Pendientes de decisión del broker (pestaña Por validar).
  static const List<String> adminPendingValidation = [
    pendiente,
  ];

  /// Entregados o rechazados (pestaña Pedidos cerrados).
  static const List<String> adminClosedOrders = [
    entregado,
    rechazado,
  ];

  /// Pedido en curso post-aprobación (aliado — agrupación en vista Pedidos).
  static const List<String> aliadoPedidosEnCurso = [
    aprobadoAdmin,
    enPreparacion,
    enTransito,
  ];

  /// Estados que suman `precio_total` contra el límite de crédito del aliado.
  static const List<String> aliadoCreditExposureStatuses = [
    pendiente,
    aprobadoAdmin,
    enPreparacion,
    enTransito,
  ];

  /// Aliado: pestaña Pedidos = en curso + cerrados (excluye pendiente).
  static const List<String> aliadoPedidosActivosYCerrados = [
    aprobadoAdmin,
    enPreparacion,
    enTransito,
    entregado,
    rechazado,
  ];

  static String labelEs(String status) {
    switch (status) {
      case pendiente:
        return 'Pendiente de revisión';
      case aprobadoAdmin:
        return 'Aprobado por MotoLink';
      case rechazado:
        return 'Rechazado';
      case enPreparacion:
        return 'En preparación';
      case enTransito:
        return 'En tránsito';
      case entregado:
        return 'Entregado';
      default:
        return status;
    }
  }

  /// Siguiente estado que puede aplicar el importador, o null si es terminal o no aplica.
  /// `en_preparacion` → `en_transito` lo registra MotoLink (con factura y días de ETA).
  static String? nextForImporter(String current) {
    switch (current) {
      case aprobadoAdmin:
        return enPreparacion;
      case enPreparacion:
        return null;
      case enTransito:
        return entregado;
      default:
        return null;
    }
  }

  static String actionLabelForNext(String nextStatus) {
    switch (nextStatus) {
      case enPreparacion:
        return 'Marcar en preparación';
      case enTransito:
        return 'Marcar en tránsito';
      case entregado:
        return 'Marcar entregado';
      default:
        return 'Avanzar';
    }
  }

  /// Texto corto para la vista importador: operación vs cerrado.
  static String importerOperationalHeadline(String status) {
    switch (status) {
      case entregado:
        return 'Pedido cerrado';
      case rechazado:
        return '—';
      default:
        if (importerPipeline.contains(status)) {
          return 'Pedido activo';
        }
        return '—';
    }
  }

  /// Mensaje corto para el aliado (seguimiento del pedido).
  static String aliadoTrackingHeadline(String status) {
    switch (status) {
      case pendiente:
        return 'En revisión por MotoLink';
      case rechazado:
        return 'Solicitud no aprobada';
      case aprobadoAdmin:
        return 'Aprobado · preparación pendiente';
      case enPreparacion:
        return 'Tu pedido se está preparando';
      case enTransito:
        return 'En tránsito hacia tu taller';
      case entregado:
        return 'Pedido completado';
      default:
        return '—';
    }
  }
}
