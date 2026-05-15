import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'courier_timeline_widget.dart';
import 'transportista_recogida_almacen_section.dart';
import 'importer_aliado_solicitud_section.dart';
import 'transaction_request_admin_sections.dart';

/// Ficha compacta para importador: resumen, acción rápida, detalle con aliado y fechas.
class ImporterExpandableOrderCard extends StatelessWidget {
  const ImporterExpandableOrderCard({
    super.key,
    required this.request,
    this.checkoutGroupLines,
    required this.expanded,
    required this.onToggle,
    required this.statusLabel,
    this.operationalHeadline,
    this.nextStatus,
    this.nextActionLabel,
    this.onAdvance,
    this.expandedFooter,
  });

  final TransactionRequestModel request;

  /// Mismo carrito del aliado: varias filas con el mismo `checkout_group_id`.
  final List<TransactionRequestModel>? checkoutGroupLines;
  final bool expanded;
  final VoidCallback onToggle;
  final String statusLabel;
  final String? operationalHeadline;
  final String? nextStatus;
  final String? nextActionLabel;
  final VoidCallback? onAdvance;
  final Widget? expandedFooter;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final lines = (checkoutGroupLines != null && checkoutGroupLines!.length > 1)
        ? checkoutGroupLines!
        : <TransactionRequestModel>[r];
    final isCheckoutGroup = lines.length > 1;

    final uid = SupabaseService.currentUserId;
    final lineas = r.orderItemsParaVistaImportador(uid);
    final titulo = isCheckoutGroup
        ? tituloCheckoutGrupoImportador(lines, uid)
        : (lineas.isNotEmpty
            ? r.tituloPedidoImportador(lineas)
            : r.etiquetaProductoImportador(uid));
    final showHeadline =
        operationalHeadline != null &&
        operationalHeadline!.isNotEmpty &&
        operationalHeadline != '—';

    final destinoTxt =
        isCheckoutGroup ? lines.first.destinoEntregaLineaCompactaEs : r.destinoEntregaLineaCompactaEs;

    final anyEntregadoPago = isCheckoutGroup
        ? lines.any((x) => x.pedidoEntregadoYPagado)
        : r.pedidoEntregadoYPagado;
    final anyPagoPendienteTrasEntrega = isCheckoutGroup
        ? lines.any((x) => x.pagoMotolinkPendienteTrasEntrega)
        : r.pagoMotolinkPendienteTrasEntrega;
    final anyPagoRiesgo = isCheckoutGroup
        ? lines.any((x) => x.pagoPendienteRiesgoCuentaTresDiasHabiles)
        : r.pagoPendienteRiesgoCuentaTresDiasHabiles;

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
                              operationalHeadline!,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: r.status == TransactionRequestStatus.entregado
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
                                  titulo,
                                  maxLines: expanded ? 4 : 2,
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
                          if (isCheckoutGroup)
                            ImporterCheckoutBundleSolicitudSection(
                              lines: lines,
                              compact: true,
                              embedInOrderCard: true,
                              productDetailRows: false,
                            )
                          else
                            ImporterAliadoSolicitudSection(
                              request: r,
                              compact: true,
                              embedInOrderCard: true,
                              productDetailRows: false,
                            ),
                          const SizedBox(height: 4),
                          if (!expanded)
                            Text(
                              destinoTxt,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                height: 1.25,
                              ),
                            ),
                          if (anyEntregadoPago) ...[
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
                                isCheckoutGroup
                                    ? 'Entregado y pagado (al menos una línea validada por MotoLink).'
                                    : 'Entregado y pagado (pago validado por MotoLink).',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                          ] else if (anyPagoPendienteTrasEntrega) ...[
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
                              child: Text(
                                isCheckoutGroup
                                    ? 'Pago pendiente: revisa comprobante por línea al expandir.'
                                    : 'Pago pendiente: falta aprobar comprobante en MotoLink.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.deepOrange.shade900,
                                ),
                              ),
                            ),
                            if (anyPagoRiesgo) ...[
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
                                  '>3 días hábiles sin pago aprobado: posible restricción de nuevos pedidos.',
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
          if (nextStatus != null &&
              nextActionLabel != null &&
              onAdvance != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onAdvance,
                      child: Text(
                        isCheckoutGroup
                            ? '${nextActionLabel!} (carrito completo)'
                            : nextActionLabel!,
                      ),
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
                        TransactionRequestAliadoContactSection(request: lines.first),
                        const SizedBox(height: 12),
                        TransactionRequestDestinoEntregaSection(
                          request: lines.first,
                        ),
                        const SizedBox(height: 12),
                        TransactionRequestProductosDesgloseSection(
                          lines: lines,
                          compact: true,
                          viewer: PedidoDesgloseViewer.importador,
                        ),
                        const SizedBox(height: 12),
                        if (isCheckoutGroup) ...[
                          if (checkoutGroupMismoEstadoEnvio(lines)) ...[
                            CourierTimelineWidget(
                              request: lines.first,
                              compact: true,
                              viewerRole: AppHomeRole.importador,
                              showHeading: true,
                            ),
                            if (lines.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Ítems en este flujo: '
                                  '${tituloCheckoutGrupoImportador(lines, uid)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.35,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            for (var li = 0; li < lines.length; li++) ...[
                              if (lines[li].status ==
                                  TransactionRequestStatus.enTransito) ...[
                                const SizedBox(height: 12),
                                Text(
                                  lines[li].etiquetaGestionLineaImportador(uid),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.teal.shade100),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: TransportistaRecogidaAlmacenSection(
                                      request: lines[li],
                                      viewerRole: AppHomeRole.importador,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ] else ...[
                            const Text(
                              'Seguimiento del envío',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (var li = 0; li < lines.length; li++) ...[
                              if (li > 0) const Divider(height: 20),
                              Text(
                                lines[li].etiquetaGestionLineaImportador(uid),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CourierTimelineWidget(
                                request: lines[li],
                                compact: true,
                                viewerRole: AppHomeRole.importador,
                                showHeading: false,
                              ),
                              if (lines[li].status ==
                                  TransactionRequestStatus.enTransito) ...[
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
                                      request: lines[li],
                                      viewerRole: AppHomeRole.importador,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Ítem a gestionar: '
                              '${r.etiquetaGestionLineaImportador(uid)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          CourierTimelineWidget(
                            request: r,
                            compact: true,
                            viewerRole: AppHomeRole.importador,
                            showHeading: true,
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
                                  viewerRole: AppHomeRole.importador,
                                ),
                              ),
                            ),
                          ],
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
