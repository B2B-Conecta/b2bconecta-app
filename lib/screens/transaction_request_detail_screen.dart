import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_request_admin_pedido_listo_route_prep_section.dart';
import '../widgets/transaction_request_admin_sections.dart';

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
              const SizedBox(height: 12),
              _contactByRole(r),
              const SizedBox(height: 12),
              TransactionRequestDestinoEntregaSection(
                request: r,
                viewingAsRole: widget.homeRole,
              ),
              if ((r.status == TransactionRequestStatus.pedidoListo ||
                      r.status == TransactionRequestStatus.enTransito) &&
                  widget.homeRole == AppHomeRole.administrador) ...[
                const SizedBox(height: 12),
                TransactionRequestAdminPedidoListoRoutePrepSection(
                  request: r,
                  onSaved: _reloadRequest,
                ),
              ],
              const SizedBox(height: 12),
              TransactionRequestLifecycleSection(request: r),
              if (r.notasAdmin != null && r.notasAdmin!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _noteCard(r.notasAdmin!.trim()),
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
              r.productName ?? 'Producto',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (r.productSku != null && r.productSku!.isNotEmpty) ...[
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
                _chip('Estado: ${TransactionRequestStatus.labelEs(r.status)}'),
                _chip('Cantidad: ${r.cantidad}'),
                _chip('Total: \$${r.precioTotal.toStringAsFixed(2)}'),
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
        return TransactionRequestImporterContactSection(request: r);
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
