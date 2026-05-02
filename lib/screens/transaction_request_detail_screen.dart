import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/sub_order_status.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/courier_timeline_widget.dart';
import '../widgets/importer_aliado_solicitud_section.dart';
import '../widgets/transaction_request_admin_sections.dart';
import '../widgets/admin_transportista_assignment_section.dart';
import '../widgets/transaction_request_route_map_section.dart';
import '../widgets/transportista_assignment_ack_section.dart';
import '../widgets/transportista_recogida_almacen_section.dart';
import '../widgets/transportista_factura_aliado_section.dart';

class TransactionRequestDetailScreen extends StatefulWidget {
  const TransactionRequestDetailScreen({
    super.key,
    required this.requestId,
    required this.homeRole,
  });

  final String requestId;
  final AppHomeRole homeRole;

  @override
  State<TransactionRequestDetailScreen> createState() =>
      _TransactionRequestDetailScreenState();
}

class _TransactionRequestDetailScreenState
    extends State<TransactionRequestDetailScreen> {
  late Future<TransactionRequestModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchTransactionRequestById(widget.requestId);
  }

  void _reloadRequest() {
    setState(() {
      _future = SupabaseService.fetchTransactionRequestById(widget.requestId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detalle del pedido',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<TransactionRequestModel?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
          }
          if (snapshot.hasError) {
            return _stateText('No se pudo cargar el pedido.\n${snapshot.error}');
          }
          final r = snapshot.data;
          if (r == null) {
            return _stateText(
              'No encontramos este pedido o no tienes permisos para verlo.',
            );
          }
            return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              if (r.pedidoEntregadoYPagado) ...[
                _pagoCompletadoBanner(),
                const SizedBox(height: 12),
              ] else               if (r.pagoMotolinkPendienteTrasEntrega) ...[
                _pagoPendienteBanner(),
                if (r.pagoPendienteRiesgoCuentaTresDiasHabiles) ...[
                  const SizedBox(height: 10),
                  _pagoAtrasoCuentaBanner(),
                ],
                const SizedBox(height: 12),
              ],
              if (_mostrarBannerPedidoListo(r)) ...[
                _pedidoListoPickupBanner(),
                const SizedBox(height: 12),
              ],
              _summaryCard(r),
              if (widget.homeRole == AppHomeRole.importador) ...[
                const SizedBox(height: 12),
                ImporterAliadoSolicitudSection(request: r, compact: false),
              ],
              if (r.isMasterOrder &&
                  r.subOrders.isNotEmpty &&
                  widget.homeRole == AppHomeRole.administrador) ...[
                const SizedBox(height: 12),
                _masterImporterCards(context, r),
              ],
              const SizedBox(height: 12),
              _contactByRole(r),
              const SizedBox(height: 12),
              TransactionRequestDestinoEntregaSection(
                request: r,
                viewingAsRole: widget.homeRole,
              ),
              if (widget.homeRole == AppHomeRole.transportista) ...[
                const SizedBox(height: 12),
                TransportistaAssignmentAckSection(
                  request: r,
                  onAcknowledged: _reloadRequest,
                ),
                if (r.hasFacturaAliado) ...[
                  const SizedBox(height: 12),
                  TransportistaFacturaAliadoSection(request: r),
                ],
              ],
              if (r.status == TransactionRequestStatus.enTransito) ...[
                const SizedBox(height: 12),
                TransactionRequestRouteMapSection(request: r),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: TransportistaRecogidaAlmacenSection(
                      request: r,
                      viewerRole: widget.homeRole,
                      onUpdated: _reloadRequest,
                    ),
                  ),
                ),
              ],
              if (widget.homeRole == AppHomeRole.administrador) ...[
                const SizedBox(height: 12),
                AdminTransportistaAssignmentSection(
                  key: ValueKey<String>(
                    'detail-assign-${r.id}-${r.assignedTransportistaId ?? ''}',
                  ),
                  request: r,
                  onMutated: _reloadRequest,
                ),
              ],
              const SizedBox(height: 12),
              CourierTimelineWidget(
                request: r,
                viewerRole: widget.homeRole,
              ),
              if (r.notasAdmin != null && r.notasAdmin!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _noteCard(r.notasAdmin!.trim()),
              ],
              if (r.canceladoPorAliado &&
                  (r.aliadoCancelacionMotivo?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                _noteCard(
                  'Motivo de cancelación (aliado): ${r.aliadoCancelacionMotivo!.trim()}',
                ),
              ],
              if (r.anuladoPorMotolink &&
                  (r.motolinkAnulacionMotivo?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                _noteCard(
                  'Anulación MotoLink: ${r.motolinkAnulacionMotivo!.trim()}',
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _pagoPendienteBanner() {
    return Material(
      color: Colors.deepOrange.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.payments_outlined, color: Colors.deepOrange.shade800),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Este pedido está entregado pero Pendiente por pagar: falta que el aliado complete el '
                'comprobante o que MotoLink apruebe el pago.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _mostrarBannerPedidoListo(TransactionRequestModel r) {
    if (r.status != TransactionRequestStatus.pedidoListo) return false;
    return widget.homeRole == AppHomeRole.administrador ||
        widget.homeRole == AppHomeRole.transportista;
  }

  Widget _pedidoListoPickupBanner() {
    return Material(
      color: Colors.teal.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_active_outlined,
                color: Colors.teal.shade900),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Importador confirmó pedido listo para recolección: coordine el retiro de la carga y, '
                'tras el despacho del transportista, marque «En tránsito» desde Pedidos activos.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagoCompletadoBanner() {
    return Material(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pedido entregado y pagado: MotoLink validó el pago.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagoAtrasoCuentaBanner() {
    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Han pasado 3 o más días hábiles sin completar el pago. MotoLink puede restringir la cuenta '
                'del aliado para pedidos futuros si no se regulariza.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stateText(String t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _summaryCard(TransactionRequestModel r) {
    final uid = SupabaseService.currentUserId;
    final partidas = r.orderItemsParaVistaImportador(uid);
    final title = widget.homeRole == AppHomeRole.importador && partidas.isNotEmpty
        ? r.tituloPedidoImportador(partidas)
        : r.tituloFichaPrincipalPedido;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (!r.isMasterOrder &&
                r.productSku != null &&
                r.productSku!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'SKU: ${r.productSku}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(
                  'Estado: ${r.statusLabelEs(aliadoViewer: widget.homeRole == AppHomeRole.aliado)}',
                ),
                if (!r.isMasterOrder) _chip('Cantidad: ${r.cantidad}'),
                _chip('Total REF: \$${r.precioTotal.toStringAsFixed(2)}'),
                if (r.precioTotalBsUi != null)
                  _chip(
                    'Referencia BS: ${r.precioTotalBsUi!.toStringAsFixed(2)}',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${r.id}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _masterImporterCards(BuildContext context, TransactionRequestModel r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Por importador',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        for (final so in r.subOrders) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          so.importadorBusinessName ?? 'Importador',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          SubOrderStatus.labelEs(so.status),
                          style: const TextStyle(fontSize: 10),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  Text(
                    '${so.itemsCount} ítems · subtotal REF \$${so.montoSubtotal.toStringAsFixed(2)}'
                    '${r.tasaBcvSnapshot != null ? ' · ~${(so.montoSubtotal * r.tasaBcvSnapshot!).toStringAsFixed(2)} BS' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final it in so.orderItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '· ${it.productName ?? 'Producto'} × ${it.cantidad} '
                        '(\$${it.precioLineTotal.toStringAsFixed(2)} REF)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  if (widget.homeRole == AppHomeRole.aliado &&
                      so.status == SubOrderStatus.enRuta) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await SupabaseService.aliadoMarcaSubOrderEntregado(
                            so.id,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recepción de este tramo registrada.'),
                            ),
                          );
                          _reloadRequest();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      },
                      child: const Text('Confirmar recepción (este importador)'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _chip(String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.brandBlue,
          ),
        ),
      ),
    );
  }

  Widget _contactByRole(TransactionRequestModel r) {
    switch (widget.homeRole) {
      case AppHomeRole.aliado:
        return TransactionRequestImporterContactSection(
          request: r,
          onAliadoMarcaSubOrderEntregado:
              r.isMasterOrder && r.subOrders.isNotEmpty
                  ? (subOrderId) async {
                      try {
                        await SupabaseService.aliadoMarcaSubOrderEntregado(
                          subOrderId,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Recepción de este tramo registrada.',
                            ),
                          ),
                        );
                        _reloadRequest();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  : null,
        );
      case AppHomeRole.importador:
        return TransactionRequestAliadoContactSection(request: r);
      case AppHomeRole.administrador:
      case AppHomeRole.transportista:
        return TransactionRequestPartiesContactSection(request: r);
    }
  }

  Widget _noteCard(String note) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nota de MotoLink',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Text(note, style: const TextStyle(height: 1.35)),
          ],
        ),
      ),
    );
  }
}
