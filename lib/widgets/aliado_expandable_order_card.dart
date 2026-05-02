import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import 'courier_timeline_widget.dart';
import 'transaction_request_admin_sections.dart';
import 'transportista_recogida_almacen_section.dart';

/// Ficha compacta para aliado: resumen y detalle con importador y ciclo del envío.
class AliadoExpandableOrderCard extends StatelessWidget {
  const AliadoExpandableOrderCard({
    super.key,
    required this.request,
    required this.expanded,
    required this.onToggle,
    required this.statusLabel,
    this.onConfirmarRecepcion,
    this.confirmarRecepcionBusy = false,
    this.onCancelarSolicitudPendiente,
    this.cancelarSolicitudPendienteBusy = false,
    this.expandedFooter,
  });

  final TransactionRequestModel request;
  final bool expanded;
  final VoidCallback onToggle;
  final String statusLabel;
  /// Cuando el pedido está en tránsito: el aliado cierra el ciclo confirmando recepción.
  final VoidCallback? onConfirmarRecepcion;
  final bool confirmarRecepcionBusy;
  /// Solo aplica mientras [TransactionRequestModel.status] es pendiente.
  final VoidCallback? onCancelarSolicitudPendiente;
  final bool cancelarSolicitudPendienteBusy;
  final Widget? expandedFooter;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final puedeConfirmarRecepcion = r.transportistaCompletoRecogidaAlmacen;
    final tracking = TransactionRequestStatus.aliadoTrackingHeadline(
      r.status,
      canceladoPorAliado: r.canceladoPorAliado,
      anuladoPorMotolink: r.anuladoPorMotolink,
    );
    final showHeadline = tracking.isNotEmpty && tracking != '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeadline) ...[
                            Text(
                              tracking,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: r.status == TransactionRequestStatus.rechazado
                                    ? Colors.red.shade800
                                    : r.status == TransactionRequestStatus.entregado
                                        ? Colors.green.shade800
                                        : AppColors.brandBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.tituloFichaPrincipalPedido,
                                  maxLines: expanded ? 3 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Chip(
                                label: Text(
                                  statusLabel,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                          if (!r.isMasterOrder && r.productSku != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'SKU: ${r.productSku}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            r.isMasterOrder
                                ? '${r.subOrders.isEmpty ? 0 : r.subOrders.length} '
                                    '${r.subOrders.length == 1 ? "importador" : "importadores"} · '
                                    '${r.totalUnidadesAliado} uds · Total REF '
                                    '\$${r.precioTotal.toStringAsFixed(2)}'
                                    '${r.precioTotalBsUi != null ? " · ~${r.precioTotalBsUi!.toStringAsFixed(2)} BS" : ""}'
                                : '${r.cantidad} uds · Total estimado '
                                    '\$${r.precioTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (r.isMasterOrder && r.subOrders.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${r.subOrders.length} almacén(es) · '
                              '${r.lineasProductoCount} partida(s) de producto',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey.shade700,
                                height: 1.2,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            r.destinoEntregaLineaCompactaEs,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              height: 1.25,
                            ),
                          ),
                          if (r.aliadoPagoEstadoResumenEs != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              r.aliadoPagoEstadoResumenEs!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandBlue.withOpacity(0.95),
                                height: 1.25,
                              ),
                            ),
                          ],
                          if (r.pedidoEntregadoYPagado) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                'Entregado y pagado: MotoLink validó su pago.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: Colors.green.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ] else if (r.pagoMotolinkPendienteTrasEntrega) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Text(
                                'Pago pendiente: MotoLink aún no ha aprobado el comprobante o la declaración de pago. '
                                'Complete el registro en esta ficha cuando corresponda.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (r.pagoPendienteRiesgoCuentaTresDiasHabiles) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  'Lleva varios días hábiles sin completar el pago. Si no regulariza, MotoLink '
                                  'podría desactivar su cuenta para nuevos pedidos.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                          if (r.status == TransactionRequestStatus.enTransito &&
                              r.hasTransitEta) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Llegada estimada: ~${r.transitEtaResumenEs} desde el envío',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandBlue.withOpacity(0.95),
                              ),
                            ),
                          ],
                          if (r.muestraCreditoMotoLinkAsignadoEnPedido) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Crédito MotoLink asignado: '
                              '\$${(r.aliadoCreditLimit ?? 0).toStringAsFixed(2)} USD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandBlue.withOpacity(0.95),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            ),
          if (r.status == TransactionRequestStatus.pendiente &&
              onCancelarSolicitudPendiente != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: OutlinedButton.icon(
                onPressed: cancelarSolicitudPendienteBusy
                    ? null
                    : onCancelarSolicitudPendiente,
                icon: cancelarSolicitudPendienteBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, size: 20),
                label: Text(
                  cancelarSolicitudPendienteBusy
                      ? 'Cancelando…'
                      : 'Cancelar solicitud (antes de aprobarse)',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Solo mientras MotoLink aún no ha aprobado. Debe indicar un motivo; se notifica a MotoLink.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
          if (onConfirmarRecepcion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: confirmarRecepcionBusy || !puedeConfirmarRecepcion
                        ? null
                        : onConfirmarRecepcion,
                    icon: confirmarRecepcionBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.inventory_2_outlined, size: 20),
                    label: Text(
                      confirmarRecepcionBusy
                          ? 'Confirmando…'
                          : 'Confirmar recepción en tu taller',
                    ),
                  ),
                  if (r.status == TransactionRequestStatus.enTransito &&
                      !puedeConfirmarRecepcion) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 20, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r.isMasterOrder && r.subOrders.isNotEmpty
                                    ? 'Podrá confirmar cuando el transportista haya marcado la recogida '
                                        'en todos los almacenes de este pedido (${r.subOrdersRecogidasAlmacenCount}/${r.subOrders.length} listos).'
                                    : 'Podrá confirmar cuando el transportista haya marcado la recogida en el almacén del importador.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    request.pagoMotolinkPendienteEnTransito
                        ? 'Puede confirmar la recepción aunque el pago siga pendiente ante MotoLink. '
                            'El pedido quedará como entregado y deberá completar o esperar la aprobación '
                            'del comprobante en esta misma ficha.'
                        : 'Marca este paso cuando hayas recibido la mercancía. Se cierra el pedido y queda '
                            'registrada la fecha de entrega para MotoLink y el importador.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onToggle,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Cerrar'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        TransactionRequestImporterContactSection(request: r),
                        const SizedBox(height: 12),
                        TransactionRequestDestinoEntregaSection(
                          request: r,
                          viewingAsRole: AppHomeRole.aliado,
                        ),
                        const SizedBox(height: 12),
                        CourierTimelineWidget(request: r, compact: true),
                        if (r.status == TransactionRequestStatus.enTransito) ...[
                          const SizedBox(height: 12),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.shade100),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: TransportistaRecogidaAlmacenSection(
                                request: r,
                                viewerRole: AppHomeRole.aliado,
                              ),
                            ),
                          ),
                        ],
                        if (expandedFooter != null) ...[
                          const SizedBox(height: 12),
                          expandedFooter!,
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
