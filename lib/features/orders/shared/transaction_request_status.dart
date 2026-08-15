import 'order_flow_copy/order_status_flow_copy.dart';

/// Estados de `transaction_requests` (B2B).
abstract final class TransactionRequestStatus {
  static const pendiente = 'pendiente';
  static const aprobadoAdmin = 'aprobado_admin';
  static const rechazado = 'rechazado';
  static const enPreparacion = 'en_preparacion';
  static const pedidoListo = 'pedido_listo';
  static const enTransito = 'en_transito';
  static const enviado = 'enviado';
  static const entregado = 'entregado';

  /// Aliado: pedidos en curso (excluye cerrados).
  static const List<String> aliadoPedidosEnCurso = [
    pendiente,
    enPreparacion,
    pedidoListo,
    enTransito,
    enviado,
  ];

  /// Aliado: pestaña Pedidos = en curso + cerrados.
  static const List<String> aliadoPedidosActivosYCerrados = [
    pendiente,
    enPreparacion,
    pedidoListo,
    enTransito,
    enviado,
    entregado,
    rechazado,
  ];

  /// Cupo / pedidos abiertos (sin entregado ni rechazado).
  static const List<String> motoconectaAliadoCreditExposureStatuses = [
    pendiente,
    enPreparacion,
    pedidoListo,
    enTransito,
    enviado,
  ];

  /// Estados que suman exposición de cupo (alias; igual que [motoconectaAliadoCreditExposureStatuses]).
  static const List<String> aliadoCreditExposureStatuses = [
    pendiente,
    enPreparacion,
    pedidoListo,
    enTransito,
    enviado,
  ];

  /// Aliado: pedidos visibles (nombre histórico `motoconecta*`).
  static const List<String> motoconectaAliadoPedidosActivosYCerrados = [
    pendiente,
    enPreparacion,
    pedidoListo,
    enTransito,
    enviado,
    entregado,
    rechazado,
  ];

  /// Importador: listado unificado.
  static const List<String> motoconectaImporterOrdersUnifiedStatuses = [
    pendiente,
    enPreparacion,
    pedidoListo,
    enTransito,
    enviado,
    entregado,
    rechazado,
  ];

  /// Admin: pestaña Activos.
  static const List<String> motoconectaAdminOperationalActive = [
    pendiente,
    enPreparacion,
    pedidoListo,
    enTransito,
    enviado,
  ];

  /// Estados donde aplica `admin_anula_pedido_por_motolink`: post primera gestión, no entregado.
  static const List<String> adminAnulablePorMotolinkStatuses = [
    aprobadoAdmin,
    enPreparacion,
    pedidoListo,
    enTransito,
    enviado,
  ];

  /// Listado unificado importador: operación + cerrados (`rechazado`).
  static const List<String> importerOrdersUnifiedStatuses = [
    pendiente,
    enPreparacion,
    pedidoListo,
    enTransito,
    enviado,
    entregado,
    rechazado,
  ];

  /// Admin: pedidos en curso (incluye `pendiente` en bandeja activa).
  static const List<String> adminOperationalActive =
      motoconectaAdminOperationalActive;

  /// Entregados o rechazados (admin — cerrados).
  static const List<String> adminClosedOrders = [
    entregado,
    rechazado,
  ];

  /// Admin: bandeja unificada (operativos en curso + cerrados).
  static List<String> get adminBandejaUnifiedStatuses => [
        ...motoconectaAdminOperationalActive,
        ...adminClosedOrders,
      ];

  static bool isAdminBandejaOperational(String status) =>
      motoconectaAdminOperationalActive.contains(status);

  static bool isAdminBandejaClosed(String status) =>
      adminClosedOrders.contains(status);

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

  /// Declaración / comprobante de pago multietapa (referencia de modelo legacy).
  static const List<String> aliadoDeclaracionPagoMultietapa = [
    pendiente,
    aprobadoAdmin,
    enPreparacion,
    pedidoListo,
    enTransito,
    entregado,
  ];

  static String labelEs(String status) => OrderStatusFlowCopy.labelEs(status);

  /// Siguiente estado que puede aplicar el importador, o null si es terminal.
  /// Ciclo: pendiente → en preparación → listo para despacho → en tránsito.
  static String? nextForImporter(String current) {
    switch (current) {
      case pendiente:
        return enPreparacion;
      case enPreparacion:
        return pedidoListo;
      case pedidoListo:
        return enTransito;
      case enviado:
      case enTransito:
      case entregado:
      case rechazado:
        return null;
      default:
        return null;
    }
  }

  /// Solo el aliado cierra: en tránsito (o legado `enviado`) → `entregado` (recibido).
  static String? nextForAliado(String current) {
    if (current == enTransito || current == enviado) return entregado;
    return null;
  }

  static String importerFilterStatusLabelEs(String status) =>
      OrderStatusFlowCopy.importerFilterLabelEs(status);

  static String actionLabelForNext(String nextStatus) =>
      OrderStatusFlowCopy.actionLabelForNext(nextStatus);

  /// Etiqueta del botón de avance en panel importador (línea o carrito).
  static String importerAdvanceButtonLabel(
    String nextStatus, {
    bool checkoutGroup = false,
  }) =>
      OrderStatusFlowCopy.importerAdvanceButtonLabel(
        nextStatus,
        checkoutGroup: checkoutGroup,
      );

  static String importerOperationalHeadline(String status) =>
      OrderStatusFlowCopy.importerOperationalHeadline(status);

  static String aliadoTrackingHeadline(
    String status, {
    bool canceladoPorAliado = false,
    bool canceladoPorImportador = false,
    bool anuladoPorMotolink = false,
  }) =>
      OrderStatusFlowCopy.aliadoTrackingHeadline(
        status,
        canceladoPorAliado: canceladoPorAliado,
        canceladoPorImportador: canceladoPorImportador,
        anuladoPorMotolink: anuladoPorMotolink,
      );
}
