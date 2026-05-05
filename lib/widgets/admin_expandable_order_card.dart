import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/sub_order_status.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import 'courier_timeline_widget.dart';
import 'transaction_request_admin_sections.dart';
import 'transportista_assignment_ack_section.dart';
import 'transportista_recogida_almacen_section.dart';

/// Ficha compacta: un toque en la cabecera despliega contactos, crédito y ciclo del envío.
class AdminExpandableOrderCard extends StatelessWidget {
  const AdminExpandableOrderCard({
    super.key,
    required this.request,
    required this.expanded,
    required this.onToggle,
    required this.statusLabel,
    this.expandedFooter,
    /// Broker MotoLink vs transportista (afecta CTA de ruta y bloque «pedido listo»).
    this.cardViewerRole = AppHomeRole.administrador,
    this.onRequestMutated,
  });

  final TransactionRequestModel request;
  final bool expanded;
  final VoidCallback onToggle;
  final String statusLabel;
  final Widget? expandedFooter;
  final AppHomeRole cardViewerRole;
  final VoidCallback? onRequestMutated;

  bool get _isTransportista => cardViewerRole == AppHomeRole.transportista;

  @override
  Widget build(BuildContext context) {
    final r = request;
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
                          if (r.isMasterOrder && r.subOrders.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final so in r.subOrders)
                                  Chip(
                                    label: Text(
                                      '${so.importadorBusinessName ?? 'Importador'} · '
                                      '${SubOrderStatus.labelEs(so.status)}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${r.totalUnidadesAliado} uds · Total (aliado) '
                            '${r.precioTotal.toStringAsFixed(2)} REF',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (r.isMasterOrder) ...[
                            const SizedBox(height: 2),
                            Text(
                              r.lineasProductoCount > 0
                                  ? '${r.subOrders.length} almacén(es) · '
                                      '${r.lineasProductoCount} partida(s) de producto'
                                  : 'Pedido contenedor (ver desglose al expandir)',
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
                          if (r.status == TransactionRequestStatus.pedidoListo &&
                              !_isTransportista) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    size: 18,
                                    color: Colors.teal.shade900,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pedido listo en despacho: cuando el transporte retire la carga, '
                                      'marcar en tránsito.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.3,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.teal.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (!_isTransportista && r.pedidoEntregadoYPagado) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: Colors.green.shade800,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Entregado y pagado: MotoLink validó el pago.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.3,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (!_isTransportista &&
                              r.pagoMotolinkPendienteTrasEntrega) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.deepOrange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.payments_outlined,
                                    size: 18,
                                    color: Colors.deepOrange.shade800,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pendiente por pagar: el aliado recibió el pedido; falta comprobante '
                                      'o aprobación MotoLink.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.3,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.deepOrange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
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
                                  'Han pasado 3 o más días hábiles sin completar el pago. MotoLink puede '
                                  'restringir la cuenta del aliado para pedidos futuros si no se regulariza.',
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
                        if (_isTransportista) ...[
                          TransportistaAssignmentAckSection(
                            request: r,
                            onAcknowledged: () => onRequestMutated?.call(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TransactionRequestPartiesContactSection(request: r),
                        const SizedBox(height: 12),
                        TransactionRequestDestinoEntregaSection(
                          request: r,
                          viewingAsRole: cardViewerRole,
                        ),
                        if (!_isTransportista) ...[
                          const SizedBox(height: 12),
                          TransactionRequestDocumentPreferenceAdminSection(
                            request: r,
                          ),
                          const SizedBox(height: 12),
                          TransactionRequestAliadoExperienceAdminSection(
                            request: r,
                          ),
                          if (r.muestraCreditoMotoLinkAsignadoEnPedido) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Crédito MotoLink asignado (aliado): '
                                    '${(r.aliadoCreditLimit ?? 0).toStringAsFixed(2)} REF',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brandBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        CourierTimelineWidget(
                          request: r,
                          compact: true,
                          viewerRole: cardViewerRole,
                        ),
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
                                viewerRole: cardViewerRole,
                                onUpdated: onRequestMutated,
                              ),
                            ),
                          ),
                        ],
                        if (expandedFooter != null) ...[
                          const SizedBox(height: 8),
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
