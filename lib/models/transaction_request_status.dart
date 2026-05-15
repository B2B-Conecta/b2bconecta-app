import '../config/app_backend.dart';

/// Estados de `transaction_requests` (trazabilidad broker + importador).
abstract final class TransactionRequestStatus {
  static const pendiente = 'pendiente';
  static const aprobadoAdmin = 'aprobado_admin';
  static const rechazado = 'rechazado';
  static const enPreparacion = 'en_preparacion';
  /// Importador confirma mercancía lista en despacho (antes del retiro MotoLink).
  static const pedidoListo = 'pedido_listo';
  static const enTransito = 'en_transito';
  /// MotoConecta: importador marcó envío (logística fuera de la app).
  static const enviado = 'enviado';
  static const entregado = 'entregado';

  /// MotoConecta — aliado: pedidos visibles (incluye pendiente).
  static const List<String> motoconectaAliadoPedidosActivosYCerrados = [
    pendiente,
    enPreparacion,
    enviado,
    entregado,
    rechazado,
  ];

  /// MotoConecta — importador: listado unificado.
  static const List<String> motoconectaImporterOrdersUnifiedStatuses = [
    pendiente,
    enPreparacion,
    enviado,
    entregado,
    rechazado,
  ];

  /// MotoConecta — admin: pestaña Activos.
  static const List<String> motoconectaAdminOperationalActive = [
    pendiente,
    enPreparacion,
    enviado,
  ];

  /// MotoConecta — cupo / pedidos abiertos (sin entregado ni rechazado).
  static const List<String> motoconectaAliadoCreditExposureStatuses = [
    pendiente,
    enPreparacion,
    enviado,
  ];

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
    enviado,
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
      case enviado:
        return 'Enviado';
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
    if (kAppUsesMotoConectaBackend) {
      switch (current) {
        case pendiente:
          return enPreparacion;
        case enPreparacion:
          return enviado;
        case enviado:
        case entregado:
        case rechazado:
          return null;
        default:
          return null;
      }
    }
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
    if (kAppUsesMotoConectaBackend) {
      if (current == enviado) return entregado;
      return null;
    }
    if (current == enTransito) return entregado;
    return null;
  }

  /// Etiquetas en vista importador (ingreso directo: `aprobado_admin` = pedido nuevo).
  static String importerFilterStatusLabelEs(String status) {
    if (kAppUsesMotoConectaBackend && status == pendiente) {
      return 'Pedido nuevo';
    }
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
      case enviado:
        return 'Marcar enviado';
      case entregado:
        return 'Confirmar recepción en tu taller';
      default:
        return 'Avanzar';
    }
  }

  /// Texto corto para la vista importador: operación vs cerrado.
  static String importerOperationalHeadline(String status) {
    if (kAppUsesMotoConectaBackend) {
      switch (status) {
        case entregado:
          return 'Pedido cerrado';
        case rechazado:
          return '—';
        case enviado:
          return 'Enviado · el aliado confirma la recepción';
        case enPreparacion:
          return 'En preparación';
        case pendiente:
          return 'Nuevo pedido';
        default:
          return 'Pedido activo';
      }
    }
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
    if (kAppUsesMotoConectaBackend) {
      switch (status) {
        case pendiente:
          return 'Pendiente · el importador confirmará preparación';
        case enPreparacion:
          return 'Tu pedido se está preparando';
        case enviado:
          return 'Enviado · confirma la recepción cuando llegue';
        case entregado:
          return 'Pedido completado';
        case rechazado:
          return canceladoPorAliado
              ? 'Solicitud cancelada'
              : 'Pedido rechazado';
        default:
          return '—';
      }
    }
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
