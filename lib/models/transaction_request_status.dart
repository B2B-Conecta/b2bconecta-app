/// Estados de `transaction_requests` (trazabilidad broker + importador).
abstract final class TransactionRequestStatus {
  static const pendiente = 'pendiente';
  static const aprobadoAdmin = 'aprobado_admin';
  static const rechazado = 'rechazado';
  static const enPreparacion = 'en_preparacion';
  /// Importador confirma mercancía lista en despacho (antes del retiro MotoLink).
  static const pedidoListo = 'pedido_listo';
  static const enTransito = 'en_transito';
  static const entregado = 'entregado';

  /// Ciclo post-validación MotoLink (pestaña Pedidos del importador).
  static const List<String> importerPipeline = [
    aprobadoAdmin,
    enPreparacion,
    pedidoListo,
    enTransito,
    entregado,
  ];

  /// Listado unificado importador: operación + cerrados (`rechazado`).
  static const List<String> importerOrdersUnifiedStatuses = [
    aprobadoAdmin,
    enPreparacion,
    pedidoListo,
    enTransito,
    entregado,
    rechazado,
  ];

  /// Solo aprobados por MotoLink pendientes de la primera acción del importador (legacy / filtros).
  static const List<String> importerSoloValidadosAdmin = [
    aprobadoAdmin,
  ];

  /// Solo preparación y tránsito (legacy / filtros internos si hiciera falta).
  static const List<String> importerActiveFulfillment = [
    enPreparacion,
    pedidoListo,
    enTransito,
  ];

  /// Aprobados por MotoLink y en fulfillment (pestaña Pedidos activos — admin).
  static const List<String> adminOperationalActive = [
    aprobadoAdmin,
    enPreparacion,
    pedidoListo,
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
    pedidoListo,
    enTransito,
  ];

  /// Estados que suman `precio_total` contra el límite de crédito del aliado.
  static const List<String> aliadoCreditExposureStatuses = [
    pendiente,
    aprobadoAdmin,
    enPreparacion,
    pedidoListo,
    enTransito,
  ];

  /// Aliado: pestaña Pedidos = en curso + cerrados (excluye pendiente).
  static const List<String> aliadoPedidosActivosYCerrados = [
    aprobadoAdmin,
    enPreparacion,
    pedidoListo,
    enTransito,
    entregado,
    rechazado,
  ];

  /// Chips de filtro en reportes admin (servidor).
  static const List<String> valuesForReportFilter = [
    pendiente,
    aprobadoAdmin,
    enPreparacion,
    pedidoListo,
    enTransito,
    entregado,
    rechazado,
  ];

  /// Declaración / comprobante de pago multietapa (excluye solo `rechazado`).
  static const List<String> aliadoDeclaracionPagoMultietapa = [
    pendiente,
    aprobadoAdmin,
    enPreparacion,
    pedidoListo,
    enTransito,
    entregado,
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
      case pedidoListo:
        return 'Pedido listo';
      case enTransito:
        return 'En tránsito';
      case entregado:
        return 'Entregado';
      default:
        return status;
    }
  }

  /// Siguiente estado que puede aplicar el importador, o null si es terminal o no aplica.
  /// `pedido_listo` → `en_transito` lo registra MotoLink (RPC).
  /// La entrega la confirma el aliado (`en_transito` → `entregado`), no el importador.
  static String? nextForImporter(String current) {
    switch (current) {
      case aprobadoAdmin:
        return enPreparacion;
      case enPreparacion:
        return pedidoListo;
      case pedidoListo:
      case enTransito:
        return null;
      default:
        return null;
    }
  }

  /// Solo el aliado puede cerrar el ciclo: `en_transito` → `entregado`.
  static String? nextForAliado(String current) {
    if (current == enTransito) return entregado;
    return null;
  }

  /// Etiquetas en vista importador (ingreso directo: `aprobado_admin` = pedido nuevo).
  static String importerFilterStatusLabelEs(String status) {
    switch (status) {
      case aprobadoAdmin:
        return 'Pedido nuevo · confirme stock';
      default:
        return labelEs(status);
    }
  }

  static String actionLabelForNext(String nextStatus) {
    switch (nextStatus) {
      case enPreparacion:
        return 'Marcar en preparación';
      case pedidoListo:
        return 'Marcar pedido listo para recolección';
      case enTransito:
        return 'Marcar en tránsito';
      case entregado:
        return 'Confirmar recepción en tu taller';
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
      case pedidoListo:
        return 'Listo en despacho · MotoLink marca el tránsito al retirar';
      case enTransito:
        return 'En tránsito · el aliado confirma la entrega';
      default:
        if (importerPipeline.contains(status)) {
          return 'Pedido activo';
        }
        return '—';
    }
  }

  /// Mensaje corto para el aliado (seguimiento del pedido).
  static String aliadoTrackingHeadline(
    String status, {
    bool canceladoPorAliado = false,
    bool anuladoPorMotolink = false,
  }) {
    switch (status) {
      case pendiente:
        return 'En revisión por MotoLink';
      case rechazado:
        if (anuladoPorMotolink) {
          return 'Pedido anulado por MotoLink';
        }
        return canceladoPorAliado
            ? 'Solicitud cancelada (antes de aprobación)'
            : 'Solicitud no aprobada';
      case aprobadoAdmin:
        return 'Enviado al importador · confirma stock y preparación';
      case enPreparacion:
        return 'Tu pedido se está preparando';
      case pedidoListo:
        return 'Mercancía lista · MotoLink coordinará el envío';
      case enTransito:
        return 'En tránsito hacia tu taller';
      case entregado:
        return 'Pedido completado';
      default:
        return '—';
    }
  }
}
