/// Recepción, cancelación, cantidad, tránsito y bloqueos de avance.
abstract final class OrderActionsFlowCopy {
  // —— Recepción (aliado) ——

  static const recepcionTitulo = '¿Recibió la mercancía?';
  static const recepcionTituloMulti = 'Recepción por importador';
  static const recepcionIntro =
      'Confirme cuando el pedido llegue a su taller.';
  static const recepcionIntroMulti =
      'Confirme cada importador por separado. Después gestione el pago de cada uno.';
  static const recepcionBoton = 'Confirmar recepción';
  static const recepcionBotonTaller = 'Confirmar en mi taller';

  // —— Cancelación ——

  static const cancelarPedidoTitulo = 'Cancelar pedido';
  static const aliadoCancelarIntro =
      'Puede cancelar mientras el importador no haya adjuntado su factura. '
      'Indique el motivo; después podrá valorar el servicio.';
  static const importadorCancelarTitulo = 'Cancelar pedido (importador)';
  static String importadorCancelarIntro(String productName) =>
      'El pedido de «$productName» se cerrará y se notificará al aliado y a MotoLink. '
      'Indique el motivo; después podrá valorar al aliado.';
  static const cancelarMotivoLabel = 'Motivo de la cancelación';
  static const cancelarMotivoObligatorio = 'Motivo (obligatorio)';
  static const cancelarConfirmar = 'Confirmar cancelación';
  static const cancelarVolver = 'Volver';

  static const aliadoNoCancelaFactura =
      'No puede cancelar: el importador ya adjuntó su factura.';
  static const aliadoNoCancelaCantidad =
      'Responda primero a la propuesta de cantidad del importador.';

  // —— Ajuste de cantidad ——

  static const qtyTitulo = 'Cambio de cantidad propuesto';
  static String qtyCuerpo(int solicitada, int? ofrecida) =>
      'Usted pidió $solicitada uds.; el importador puede enviar ${ofrecida ?? '—'} uds.';
  static const qtyNotaPrefijo = 'Nota del importador:';
  static const qtyAceptar = 'Aceptar cantidad';
  static const qtyRechazar = 'Rechazar propuesta';
  static const bloqueoQtyPendiente =
      'Espere la respuesta del aliado sobre la cantidad antes de avanzar el pedido.';

  // —— Tránsito (ETA) ——

  static const transitEtaTitulo = '¿Cuándo llegará al aliado?';
  static const transitEtaIntro =
      'Indique el tiempo estimado de llegada al taller del aliado. '
      'Él verá este plazo en el seguimiento.';
  static const transitEtaDias = 'Días (0–365)';
  static const transitEtaHoras = 'Horas (0–23)';
  static const transitEtaErrorCero =
      'Indique al menos un día o una hora mayor que cero.';
  static const transitEtaConfirmar = 'Guardar y marcar en tránsito';

  // —— Valoración ——

  static const valorarTrasCancelacion = 'Valorar tras la cancelación';
  static const valorarCancelacionSubtitulo =
      'Su motivo quedó registrado. Califique al importador; puede ampliar el comentario.';
  static const valorarServicioTitulo = 'Califique cada aspecto del servicio';
  static const valorarServicioSubtitulo =
      'Deslice cada categoría (1 = Muy mal … 5 = Excelente). '
      'El promedio define la valoración general.';
  static const valoracionEsteImportador = 'Valoración de este importador';
  static const valoracionEstePedido = 'Valoración de este pedido';

  static const pedidoCanceladoPorImportador = 'Pedido cancelado por el importador';
  static const pagoPendienteBanner =
      'Pedido entregado con pago pendiente. Complete el comprobante o espere '
      'la aprobación de MotoLink.';
  static const valorarImportadorTitulo = 'Valorar al importador';
  static const valorarAliadoTitulo = 'Valorar al aliado';
  static const valorarImportadorIntro =
      'Califique cada aspecto del servicio. El promedio es la valoración general.';
  static const valorarAliadoIntro =
      'Califique la experiencia con el aliado en este pedido.';
  static const valorarComentarioOpcional =
      'Puede añadir un comentario opcional.';
  static String valorarImportadoresPendientes(int n) =>
      'Valorar importadores ($n pendientes)';

  static const pedidoCanceladoValorar =
      'Pedido cancelado. Puede valorar al importador.';
  static const valorarPendienteCarrito =
      'Valore a cada importador en su pestaña dentro de este pedido.';

  // —— Carrito multi-importador ——

  static const carritoMultiPagoIntro =
      'Cada importador emite su factura y usted paga por separado.';
  static const carritoMultiAvanceDistinto = 'Avance distinto por importador';
  static String carritoChatImportador(String? nombre) =>
      nombre != null ? 'Mensajes con $nombre' : 'Mensajes de este importador';
}
