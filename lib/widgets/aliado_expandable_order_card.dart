import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import '../utils/ves_amount_format.dart';
import '../utils/aliado_experience_utils.dart';
import '../utils/aliado_multi_importer_payment.dart';
import '../utils/aliado_order_grouping.dart';
import 'aliado_multi_importer_order_tabs.dart';
import 'aliado_order_experience_display.dart';
import 'courier_timeline_widget.dart';
import 'importer_aliado_solicitud_section.dart';
import 'transaction_request_admin_sections.dart';

/// Ficha compacta para aliado: resumen y detalle con importador y ciclo del envío.
class AliadoExpandableOrderCard extends StatelessWidget {
  const AliadoExpandableOrderCard({
    super.key,
    required this.request,
    this.checkoutGroupLines,
    required this.expanded,
    required this.onToggle,
    required this.statusLabel,
    this.onCancelarSolicitudPendiente,
    this.cancelarSolicitudPendienteBusy = false,
    this.expandedLeading,
    this.expandedFooter,
    this.multiImporterPanelBuilder,
  });

  final TransactionRequestModel request;
  /// Varias filas del mismo carrito (mismo `checkout_group_id`). Si es una sola fila, dejar null.
  final List<TransactionRequestModel>? checkoutGroupLines;
  final bool expanded;
  final VoidCallback onToggle;
  final String statusLabel;
  /// Contenido al inicio de la ficha expandida (p. ej. confirmar recepción).
  final Widget? expandedLeading;
  /// Solo aplica mientras [TransactionRequestModel.status] es pendiente.
  final VoidCallback? onCancelarSolicitudPendiente;
  final bool cancelarSolicitudPendienteBusy;
  final Widget? expandedFooter;

  /// Carrito multi-importador: factura, pago y mensajes por proveedor (pestañas).
  final Widget Function(
    BuildContext context,
    List<TransactionRequestModel> chunk,
    int importerIndex,
    int importerTotal,
  )? multiImporterPanelBuilder;

  @override
  Widget build(BuildContext context) {
    final lines = (checkoutGroupLines != null && checkoutGroupLines!.isNotEmpty)
        ? checkoutGroupLines!
        : <TransactionRequestModel>[request];
    final isCheckoutGroup = lines.length > 1;
    final r = request;
    final distinctImporterIds = lines
        .map((e) => e.ownerId.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    /// Mismo almacén en todas las líneas: un solo bloque de contacto B2B.
    final consolidarDatosImportador =
        isCheckoutGroup && distinctImporterIds.length <= 1;
    final useMultiImporterTabs =
        isCheckoutGroup && multiImporterPanelBuilder != null;
    final porImportador =
        useMultiImporterTabs ? groupCheckoutLinesByImportador(lines) : const <List<TransactionRequestModel>>[];
    final String tracking;
    final bool showHeadline;
    if (isCheckoutGroup) {
      final sameStatus = lines.every((x) => x.status == lines.first.status);
      tracking = sameStatus
          ? TransactionRequestStatus.aliadoTrackingHeadline(
              lines.first.status,
              canceladoPorAliado: lines.first.canceladoPorAliado,
              anuladoPorMotolink: lines.first.anuladoPorMotolink,
            )
          : 'Varias líneas en distinto estado';
      showHeadline = tracking.isNotEmpty && tracking != '—';
    } else {
      tracking = TransactionRequestStatus.aliadoTrackingHeadline(
        r.status,
        canceladoPorAliado: r.canceladoPorAliado,
        anuladoPorMotolink: r.anuladoPorMotolink,
      );
      showHeadline = tracking.isNotEmpty && tracking != '—';
    }

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
                                color: isCheckoutGroup &&
                                        !lines.every((x) => x.status == lines.first.status)
                                    ? AppColors.brandBlue
                                    : r.status == TransactionRequestStatus.rechazado
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
                                  isCheckoutGroup
                                      ? tituloCheckoutGrupoAliado(lines)
                                      : r.etiquetaProductoAliado,
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
                          if (isCheckoutGroup &&
                              distinctImporterIds.length > 1) ...[
                            const SizedBox(height: 6),
                            _MultiImporterPagoResumenChip(lines: lines),
                          ],
                          if (lineasEntregadasParaValorar(lines).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                AliadoOrderExperienceStatusChip(
                                  request: r,
                                  linesForGroup: lines,
                                ),
                              ],
                            ),
                          ],
                          if (!isCheckoutGroup &&
                              !r.isMasterOrder &&
                              r.productSku != null) ...[
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
                            isCheckoutGroup
                                ? _checkoutGroupResumen(lines)
                                : (r.isMasterOrder
                                    ? '${r.totalUnidadesAliado} uds · '
                                        '${formatRefAmount(r.precioTotal)} REF'
                                        '${r.precioTotalBsUi != null ? " · ~${formatVesAmount(r.precioTotalBsUi!)} Bs" : ""}'
                                        '${r.subOrders.length > 1 ? " · ${r.subOrders.length} importadores" : ""}'
                                        '${(r.lineasProductoCount > 1 || r.subOrders.length > 1) ? " · ${r.lineasProductoCount} prod." : ""}'
                                    : '${r.cantidad} uds · '
                                        '${formatRefAmount(r.precioTotal)} REF'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!expanded) ...[
                            const SizedBox(height: 4),
                            Text(
                              lines.first.destinoEntregaLineaCompactaEs,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                height: 1.25,
                              ),
                            ),
                          ],
                          if (!isCheckoutGroup &&
                              r.aliadoPagoEstadoResumenEs != null &&
                              !r.pedidoEntregadoYPagado &&
                              !r.pagoMotolinkPendienteTrasEntrega) ...[
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
                          if (!isCheckoutGroup && r.pedidoEntregadoYPagado) ...[
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
                                'Entregado y pagado.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: Colors.green.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ] else if (!isCheckoutGroup && r.pagoMotolinkPendienteTrasEntrega) ...[
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
                                'Pago pendiente de revisión MotoLink.',
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
                                  '>3 días hábiles sin pago: posible restricción de nuevos pedidos.',
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
                          if (!isCheckoutGroup &&
                              !expanded &&
                              r.status == TransactionRequestStatus.enTransito &&
                              r.hasTransitEta) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Llegada ~${r.transitEtaResumenEs}',
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
          if (onCancelarSolicitudPendiente != null &&
              (!isCheckoutGroup
                  ? r.status == TransactionRequestStatus.pendiente
                  : lines.every(
                      (l) =>
                          l.status == TransactionRequestStatus.pendiente,
                    ))) ...[
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
                      : isCheckoutGroup
                          ? 'Cancelar carrito'
                          : 'Cancelar pedido',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Solo si sigue pendiente; motivo obligatorio.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
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
                        if (expandedLeading != null) expandedLeading!,
                        if (isCheckoutGroup) ...[
                          if (useMultiImporterTabs) ...[
                            AliadoPedidoMaestroHeader(
                              allLines: lines,
                              porImportador: porImportador,
                            ),
                            const SizedBox(height: 14),
                          ],
                          TransactionRequestDestinoEntregaSection(
                            request: lines.first,
                          ),
                          const SizedBox(height: 12),
                          TransactionRequestProductosDesgloseSection(
                            lines: lines,
                            compact: true,
                            viewer: PedidoDesgloseViewer.aliado,
                            showPrecioHelp: false,
                            sectionTitle: useMultiImporterTabs
                                ? 'Resumen de productos (todos los proveedores)'
                                : null,
                            showImporterGroupHeaders: true,
                          ),
                          const SizedBox(height: 12),
                          if (useMultiImporterTabs) ...[
                            AliadoMultiImporterOrderTabs(
                              allLines: lines,
                              porImportador: porImportador,
                              importerPanelBuilder: multiImporterPanelBuilder!,
                            ),
                          ] else ...[
                            if (consolidarDatosImportador) ...[
                              TransactionRequestImporterContactSection(
                                request: lines.first,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (checkoutGroupMismoEstadoEnvio(lines)) ...[
                              CourierTimelineWidget(
                                request: lines.first,
                                compact: true,
                                viewerRole: AppHomeRole.aliado,
                                showHeading: true,
                              ),
                              ..._postTimelineBloquesAliado(
                                lines: lines,
                                consolidarDatosImportador: consolidarDatosImportador,
                              ),
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
                              ..._postTimelineBloquesAliado(
                                lines: lines,
                                consolidarDatosImportador: consolidarDatosImportador,
                                timelinePorLinea: true,
                              ),
                            ],
                          ],
                        ] else ...[
                          TransactionRequestImporterContactSection(request: r),
                          const SizedBox(height: 12),
                          TransactionRequestDestinoEntregaSection(
                            request: r,
                          ),
                          const SizedBox(height: 12),
                          TransactionRequestProductosDesgloseSection(
                            lines: <TransactionRequestModel>[r],
                            compact: true,
                            viewer: PedidoDesgloseViewer.aliado,
                            showPrecioHelp: false,
                          ),
                          const SizedBox(height: 12),
                          CourierTimelineWidget(
                            request: r,
                            compact: true,
                            viewerRole: AppHomeRole.aliado,
                            showHeading: true,
                          ),
                        ],
                        if (!useMultiImporterTabs && expandedFooter != null) ...[
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

/// Tras el timeline: contacto por importador (si no está unificado arriba) y bloques de recogida por línea en tránsito.
/// Los productos no se repiten aquí (están en «Productos de tu pedido»).
List<Widget> _postTimelineBloquesAliado({
  required List<TransactionRequestModel> lines,
  required bool consolidarDatosImportador,
  bool timelinePorLinea = false,
}) {
  final out = <Widget>[];
  if (timelinePorLinea) {
    for (var i = 0; i < lines.length; i++) {
      if (out.isNotEmpty) {
        out.add(Divider(height: 1, color: Colors.grey.shade300));
        out.add(const SizedBox(height: 12));
      }
      if (!consolidarDatosImportador) {
        out.add(TransactionRequestImporterContactSection(request: lines[i]));
        out.add(const SizedBox(height: 12));
      }
      out.add(
        CourierTimelineWidget(
          request: lines[i],
          compact: true,
          viewerRole: AppHomeRole.aliado,
          showHeading: false,
        ),
      );
    }
  } else {
    if (!consolidarDatosImportador) {
      for (var i = 0; i < lines.length; i++) {
        if (i > 0) {
          out.add(Divider(height: 1, color: Colors.grey.shade300));
          out.add(const SizedBox(height: 12));
        }
        out.add(TransactionRequestImporterContactSection(request: lines[i]));
      }
      if (lines.isNotEmpty) {
        out.add(const SizedBox(height: 12));
      }
    }
  }
  return out;
}

class _MultiImporterPagoResumenChip extends StatelessWidget {
  const _MultiImporterPagoResumenChip({required this.lines});

  final List<TransactionRequestModel> lines;

  @override
  Widget build(BuildContext context) {
    final porImp = groupCheckoutLinesByImportador(lines);
    final n = porImp.length;
    if (n < 2) return const SizedBox.shrink();
    final ok = importadoresConPagoConfirmado(porImp);
    final color = ok == n ? Colors.green.shade700 : AppColors.brandBlue;

    return Chip(
      avatar: Icon(
        ok == n ? Icons.check_circle : Icons.payments_outlined,
        size: 16,
        color: color,
      ),
      label: Text(
        '$n pagos · $ok confirmado${ok == 1 ? '' : 's'}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.35)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

String _checkoutGroupResumen(List<TransactionRequestModel> lines) {
  if (lines.isEmpty) return '';
  final uds = lines.fold<int>(0, (a, r) => a + r.cantidad);
  final totalRef = lines.fold<double>(0, (a, r) => a + r.precioTotal);
  final imp = lines.length;
  final buf = StringBuffer(
    '$imp ${imp == 1 ? "importador" : "importadores"} · $uds uds · '
    '${formatRefAmount(totalRef)} REF',
  );
  final bsVals = lines.map((r) => r.precioTotalBsUi).whereType<double>().toList();
  if (bsVals.length == lines.length && bsVals.isNotEmpty) {
    final sumBs = bsVals.fold<double>(0, (a, b) => a + b);
    buf.write(' · ~${formatVesAmount(sumBs)} Bs');
  }
  if (lines.any(
        (r) => r.discountRules != null && r.discountRules!.isNotEmpty,
      )) {
    buf.write(' · descuentos volumen en ficha');
  }
  return buf.toString();
}
