import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';

/// Etiqueta de estado en listas (sin «Moroso»; usar [MorosoOrderStatusChip] aparte).
String orderListStatusLabel(
  TransactionRequestModel r, {
  bool aliadoViewer = false,
}) =>
    r.statusLabelEs(aliadoViewer: aliadoViewer);

/// Chips de cabecera: estado logístico + moroso (si aplica).
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
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text(
            statusLabel,
            style: const TextStyle(fontSize: 10),
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

/// Chip naranja «Moroso» (único indicador en ficha colapsada).
class MorosoOrderStatusChip extends StatelessWidget {
  const MorosoOrderStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: const Text(
        'Moroso',
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

    final msg = _detailMessage(request, aliadoViewer: aliadoViewer);

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

String _detailMessage(
  TransactionRequestModel request, {
  required bool aliadoViewer,
}) {
  final faltaFactura = !request.hasProveedorFactura;
  if (aliadoViewer) {
    if (faltaFactura) {
      return 'Pago pendiente tras la recepción. Cuando el importador adjunte su factura, '
          'registre su comprobante en la sección de pago.';
    }
    return 'Pago pendiente de aprobación por el importador. Registre o actualice su comprobante '
        'en la sección de pago.';
  }
  if (faltaFactura) {
    return 'Entregado sin pago aprobado. Factura del importador pendiente; '
        'el aliado debe registrar comprobante cuando corresponda.';
  }
  return 'Pago pendiente de verificación. Revise el comprobante del aliado.';
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
