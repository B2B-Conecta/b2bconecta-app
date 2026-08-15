import 'package:motolink_pro_app/features/logistics/carrier_decision.dart';
import 'transaction_request_model.dart';

/// Textos del flujo pedido listo → transporte → recolección → en tránsito.
abstract final class OrderPickupFlowCopy {
  // —— Aliado: transporte ——

  static const aliadoTransporteTitulo = '¿Cómo se entrega este pedido?';
  static const aliadoTransporteIntro =
      'La mercancía está lista en el importador. Elija quién la transporta:';

  static const aliadoTransporteElegidoTitulo = 'Transportista confirmado';
  static String aliadoTransporteElegidoCuerpo(String? carrierName) =>
      '${carrierName ?? 'El transportista elegido'} retirará el pedido. '
      'El importador le indicará el punto de recolección.';

  static const aliadoTransportePendienteFactura =
      'Cuando el importador adjunte la factura y confirme la recolección, '
      'podrá marcar el envío como en tránsito.';

  static const aliadoEntregaPropiaTitulo = 'Entrega a elección del importador';
  static const aliadoEntregaPropiaCuerpo =
      'No seleccionó un transportista del catálogo. '
      'El importador coordinará el retiro y le indicará el punto de recolección.';

  static const aliadoSkipDialogTitulo = '¿Dejamos la entrega a criterio del importador?';
  static const aliadoSkipDialogCuerpo =
      'No elegirá un transportista del catálogo. '
      'El importador definirá cómo y dónde se entrega la mercancía.';

  static const aliadoSkipBoton = 'A elección del importador';
  static const aliadoSkipExito =
      'Listo: el importador coordinará la entrega. Le avisaremos cuando indique el punto de recolección.';

  static const aliadoElegirTransportista = 'Elegir transportista';
  static const aliadoCambiarTransportista = 'Cambiar transportista';

  static const aliadoSinTransportistasElegiblesTitulo =
      'Sin transportistas para su zona';
  static const aliadoSinTransportistasElegiblesCuerpo =
      'El importador tiene transportistas activos, pero ninguno cubre su '
      'dirección de entrega. Puede dejar la entrega a elección del importador '
      'o pedirle que ajuste la cobertura.';

  static const aliadoFleteFacturaTitulo = '¿Cómo facturar el flete?';
  static const aliadoFleteFacturaIntro =
      'Indique si prefiere una sola factura del importador o dos por separado.';
  static const aliadoFleteIncluidoTitulo = 'Una factura con el flete incluido';
  static const aliadoFleteIncluidoCuerpo =
      'El importador incluirá el monto del transporte en su factura de mercancía.';
  static const aliadoFleteSeparadoTitulo = 'Dos facturas por separado';
  static const aliadoFleteSeparadoCuerpo =
      'Factura del importador por la mercancía y factura aparte del transportista.';

  // —— Importador: transporte ——

  static const importadorPasoTransporte = 'Paso 1 · Transporte';

  static const importadorEsperaAliadoTitulo = 'Esperando al aliado';
  static const importadorEsperaAliadoCuerpo =
      'Debe elegir un transportista del catálogo o dejar la entrega a elección del importador.';

  static const importadorAliadoSinPlataformaTitulo = 'Entrega a elección del importador';
  static const importadorAliadoSinPlataformaCuerpo =
      'El aliado no eligió transportista del catálogo. Indique dónde retiran la mercancía.';

  static const importadorSinTransportistasTitulo = 'Entrega sin transportista del catálogo';
  static const importadorSinTransportistasCuerpo =
      'No tiene transportistas activos. Indique dónde el aliado o su transporte retirará el pedido.';

  static const importadorTransportistaPendienteTitulo = 'Falta elegir transportista';
  static const importadorTransportistaPendienteCuerpo =
      'El aliado aún no ha confirmado cuál transportista del catálogo usará.';

  static const importadorTransportistaElegidoTitulo = 'Transportista del aliado';

  // —— Importador: recolección ——

  static const importadorPasoRecoleccion = 'Paso 2 · Punto de recolección';

  static const importadorEsperaParaRecoleccion =
      'Cuando el aliado defina el transporte, podrá indicar aquí dónde retiran la mercancía.';

  static const importadorRecoleccionTuTurnoTitulo = 'Indique dónde retiran la mercancía';
  static String importadorRecoleccionConTransportista(String? carrierName) =>
      '${carrierName ?? 'El transportista'} retirará el pedido. Elija la dirección de recolección.';
  static const importadorRecoleccionEntregaAliado =
      'El aliado dejó la entrega a su criterio. Indique dónde retiran la mercancía.';
  static const importadorRecoleccionGenerica =
      'Elija si retiran desde su almacén, la base del transportista u otra ubicación guardada.';

  static const importadorRecoleccionBoton = 'Elegir punto de recolección';
  static const importadorRecoleccionExito =
      'Punto de recolección guardado. Ya puede marcar «En tránsito» cuando tenga la factura lista.';

  static const importadorRecoleccionDialogTitulo = '¿Dónde retiran la mercancía?';
  static const importadorAlmacenSubtitulo = 'Dirección de su perfil o almacén principal';
  static const importadorBaseTransportistaSubtitulo = 'Sede o patio del transportista elegido';
  static const importadorUbicacionAlternaSubtitulo = 'Otra dirección que guardó previamente';

  // —— Compartido: visualización ——

  static const recoleccionTitulo = 'Punto de recolección';
  static const recoleccionPendienteImportador =
      'El importador aún no indicó dónde retiran la mercancía.';
  static const recoleccionPendienteGenerico =
      'Pendiente de confirmar por el importador.';

  static const abrirMapas = 'Ver en mapas';

  // —— Bloqueos al avanzar ——

  static const bloqueoEsperaAliadoTransporte =
      'Primero el aliado debe definir el transporte (elegir transportista o dejar la entrega a elección del importador).';
  static const bloqueoFaltaRecoleccion =
      'Antes de «En tránsito», elija el punto de recolección en la sección del pedido.';
  static const bloqueoFaltaTransportista =
      'El aliado debe elegir un transportista del catálogo antes de marcar «En tránsito».';

  // —— Ubicaciones alternas (config) ——

  static const ubicacionesTitulo = 'Ubicaciones de recolección';
  static const ubicacionesIntro =
      'Guarde direcciones adicionales para usarlas al confirmar dónde retiran los pedidos.';
  static const ubicacionesVacias =
      'Aún no tiene ubicaciones guardadas. Puede usar su almacén o la base del transportista.';

  // —— Detalle / admin ——

  static const detalleListoRecoleccion =
      'Pedido listo en el importador. Coordine el retiro según el punto de recolección indicado.';
  static const detalleListoEsperando =
      'Pedido listo en el importador. Aún falta confirmar dónde retiran la mercancía.';

  static String importadorRecoleccionCuerpo(TransactionRequestModel r) {
    return switch (r.carrierDecision) {
      CarrierDecision.selected => importadorRecoleccionConTransportista(
          r.carrierDisplayCompanyName,
        ),
      CarrierDecision.skipped => importadorRecoleccionEntregaAliado,
      _ => importadorRecoleccionGenerica,
    };
  }
}
