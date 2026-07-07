import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../utils/order_flow_copy/order_payment_flow_copy.dart';
import '../utils/order_flow_copy/order_vocab.dart';
import '../utils/b2b_orders_panel_layout.dart';

/// Etiqueta de estado en listas (sin chip de pago; usar [MorosoOrderStatusChip] aparte).
String orderListStatusLabel(
  TransactionRequestModel r, {
  bool aliadoViewer = false,
}) =>
    r.statusLabelEs(aliadoViewer: aliadoViewer);

/// Chips de cabecera: estado logístico + pago pendiente (si aplica).
class OrderStatusHeaderChips extends StatelessWidget {
  const OrderStatusHeaderChips({
    super.key,
    required this.statusLabel,
    required this.showMoroso,
  });

  final String statusLabel;
  final bool showMoroso;

  @override
  Widget build(BuildContext context) {
    final density = B2bOrderCardDensityScope.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text(
            statusLabel,
            style: TextStyle(fontSize: density.chipLabelSize),
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        if (showMoroso) const MorosoOrderStatusChip(),
      ],
    );
  }
}

/// Chip «Pago pendiente» en ficha colapsada.
class MorosoOrderStatusChip extends StatelessWidget {
  const MorosoOrderStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: const Text(
        OrderVocab.chipPagoPendiente,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.deepOrange.shade700,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Aviso detallado (solo ficha expandida o sección de pago).
class MorosoOrderDetailNotice extends StatelessWidget {
  const MorosoOrderDetailNotice({
    super.key,
    required this.request,
    this.aliadoViewer = false,
    this.compact = false,
  });

  final TransactionRequestModel request;
  final bool aliadoViewer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!request.esPedidoMoroso) return const SizedBox.shrink();

    final msg = aliadoViewer
        ? OrderPaymentFlowCopy.morosoDetalleAliado(request)
        : OrderPaymentFlowCopy.morosoDetalleImportador(request);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepOrange.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.payments_outlined,
            size: compact ? 18 : 20,
            color: Colors.deepOrange.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                fontSize: compact ? 11 : 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Colors.deepOrange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// En la ficha del pedido: sin aviso extra si está colapsada (basta el chip).
class MorosoOrderCardNotice extends StatelessWidget {
  const MorosoOrderCardNotice({
    super.key,
    required this.request,
    required this.expanded,
    this.aliadoViewer = false,
    this.riskWarningChild,
  });

  final TransactionRequestModel request;
  final bool expanded;
  final bool aliadoViewer;
  final Widget? riskWarningChild;

  @override
  Widget build(BuildContext context) {
    if (!request.esPedidoMoroso) return const SizedBox.shrink();
    if (!expanded) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MorosoOrderDetailNotice(
          request: request,
          aliadoViewer: aliadoViewer,
          compact: true,
        ),
        if (riskWarningChild != null) ...[
          const SizedBox(height: 8),
          riskWarningChild!,
        ],
      ],
    );
  }
}

/// Alias de compatibilidad.
class MorosoOrderBanner extends MorosoOrderDetailNotice {
  const MorosoOrderBanner({
    super.key,
    required super.request,
    super.aliadoViewer = false,
    super.compact = false,
  });
}
