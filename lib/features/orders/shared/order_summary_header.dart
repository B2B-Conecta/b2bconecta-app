import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'order_card_direct_summary.dart';
import 'importer_order_date.dart';
import 'transaction_request_model.dart';
import 'transaction_request_status.dart';
import 'order_status_label.dart';
import 'order_detail_overview.dart';

/// Presentation only: all business actions remain owned by the order panels.
class OrderSummaryHeader extends StatelessWidget {
  const OrderSummaryHeader(
      {super.key,
      required this.lines,
      required this.viewerRole,
      required this.expanded,
      required this.onToggle,
      required this.statusLabel,
      required this.chatAction,
      this.onCancel,
      this.showToggle = true,
      this.detailSummary = false,
      this.cancelBusy = false});

  final List<TransactionRequestModel> lines;
  final AppHomeRole viewerRole;
  final bool expanded;
  final VoidCallback onToggle;
  final String statusLabel;
  final Widget chatAction;
  final VoidCallback? onCancel;
  final bool cancelBusy;
  final bool showToggle;
  final bool detailSummary;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final r = lines.first;
    final scheme = Theme.of(context).colorScheme;
    final closed = lines.every((l) =>
        l.status == TransactionRequestStatus.entregado ||
        l.status == TransactionRequestStatus.rechazado);
    final sameState = lines.every((l) => l.status == r.status);
    final warning =
        lines.any((l) => l.esPedidoMoroso || l.qtyAdjustmentPendienteAliado);
    final label = !sameState
        ? (closed ? 'Cerrado' : 'En curso')
        : r.status == TransactionRequestStatus.entregado &&
                lines.every((l) => l.pedidoEntregadoYPagado)
            ? 'Completado'
            : orderStatusLabel(r.status);
    final Color statusColor = warning
        ? scheme.error
        : !sameState
            ? scheme.primary
            : switch (r.status) {
                TransactionRequestStatus.entregado =>
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.green.shade300
                      : AppColors.successGreen,
                TransactionRequestStatus.rechazado => AppColors.textSecondary,
                _ => scheme.primary,
              };
    final date = ImporterOrderDate.fechaGrupoParaFiltro(lines);
    final quantities = lines.fold<int>(0, (sum, l) => sum + l.cantidad);
    final total = lines.fold<double>(0, (sum, l) => sum + l.precioTotal);
    final parties =
        orderCardRelatedParties(lines: lines, viewerRole: viewerRole);
    final partyLabel = parties.isEmpty
        ? 'Pedido'
        : parties.length == 1
            ? parties.first.displayName
            : '${parties.first.displayName} y ${parties.length - 1} más';
    final products = orderCardProductPeeks(lines: lines);
    final title =
        products.isEmpty ? 'Productos del pedido' : products.first.name;
    final pendingQty = lines.any((l) => l.qtyAdjustmentPendienteAliado);
    final step = _nextStep(lines, viewerRole);
    final buttonLabel = expanded
        ? 'Ocultar detalle'
        : pendingQty && viewerRole == AppHomeRole.aliado
            ? 'Revisar cantidad'
            : 'Ver pedido';
    final amount = '${formatRefAmount(total)} ${orderAmountCurrency(lines)}';
    final cancelAction = PopupMenuButton<String>(
      tooltip: 'Más opciones del pedido',
      enabled: !cancelBusy,
      onSelected: (_) => onCancel!(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'cancel', child: Text('Cancelar pedido'))
      ],
      icon: cancelBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.more_horiz),
    );
    if (detailSummary) {
      return OrderDetailOverview(
          lines: lines,
          nextStep: step,
          chatAction: chatAction,
          cancelAction: onCancel == null ? null : cancelAction);
    }
    final productSummary = InkWell(
      onTap: showToggle ? onToggle : null,
      borderRadius: BorderRadius.circular(4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            detailSummary
                ? '${products.length} ${products.length == 1 ? 'repuesto' : 'repuestos'} · $quantities ${quantities == 1 ? 'unidad' : 'unidades'}'
                : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        if (!detailSummary) ...[
          const SizedBox(height: 5),
          Text(
              '$quantities ${quantities == 1 ? 'unidad' : 'unidades'}${products.length > 1 ? ' · ${products.length} productos' : ''}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 4),
        Text(partyLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13, height: 1.25, color: AppColors.textSecondary)),
      ]),
    );
    Widget amountSummary(CrossAxisAlignment alignment) => Column(
          crossAxisAlignment: alignment,
          children: [
            Text(amount,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (orderAmountCurrency(lines) == 'REF' &&
                lines.every((l) => l.precioTotalBsUi != null)) ...[
              const SizedBox(height: 3),
              Text(
                  formatBsLabel(lines.fold<double>(
                      0, (sum, l) => sum + l.precioTotalBsUi!)),
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ],
        );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child: Text(
                  date == null
                      ? 'Fecha no disponible'
                      : ImporterOrderDate.formatFechaPedido(date),
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ))),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final amountWidth = (TextPainter(
            text: TextSpan(
                text: amount,
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout())
              .width;
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(18) > 23 ||
              amountWidth > (constraints.maxWidth - 12) * 0.4) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  productSummary,
                  const SizedBox(height: 10),
                  amountSummary(CrossAxisAlignment.start),
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: productSummary),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: amountSummary(CrossAxisAlignment.end)),
          ]);
        }),
        if (!detailSummary && step.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                warning
                    ? Icons.info_outline
                    : closed
                        ? Icons.check_circle_outline
                        : Icons.schedule_outlined,
                size: 16,
                color: warning ? scheme.error : AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
                child: Text(step,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color:
                            warning ? scheme.error : AppColors.textSecondary))),
          ]),
        ],
        const SizedBox(height: 12),
        if (detailSummary)
          Row(children: [
            Expanded(
                child: Text(step,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color:
                            warning ? scheme.error : AppColors.textSecondary))),
            const SizedBox(width: 8),
            chatAction,
            if (onCancel != null) cancelAction,
          ])
        else
          Row(children: [
            if (showToggle)
              Expanded(
                  child: OutlinedButton(
                onPressed: onToggle,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: scheme.primary,
                    side: BorderSide(color: AppColors.borderSubtle)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(expanded ? Icons.expand_less : Icons.arrow_forward,
                          size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                          child:
                              Text(buttonLabel, textAlign: TextAlign.center)),
                    ]),
              )),
            if (!showToggle)
              Expanded(
                  child: Text(
                      lines.map((line) => line.ownerId).toSet().length > 1
                          ? 'Mensajes del pedido'
                          : 'Consultar al proveedor',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            chatAction,
            if (onCancel != null) cancelAction,
          ]),
      ]),
    );
  }
}

String _nextStep(List<TransactionRequestModel> lines, AppHomeRole viewer) {
  final r = lines.first;
  if (lines.any((l) => l.qtyAdjustmentPendienteAliado)) {
    return viewer == AppHomeRole.aliado
        ? 'Confirma la cantidad propuesta por el proveedor.'
        : 'Esperando la respuesta de la tienda sobre la cantidad.';
  }
  if (lines.any((l) => l.esPedidoMoroso)) {
    return viewer == AppHomeRole.aliado
        ? 'Revisa el pago pendiente de este pedido.'
        : 'Hay un pago pendiente de confirmar.';
  }
  if (lines.any((l) => l.status != r.status)) {
    return 'Consulta el avance de los productos del pedido.';
  }
  if (r.status == TransactionRequestStatus.rechazado) {
    return 'Puedes consultar el historial de este pedido.';
  }
  if (r.status == TransactionRequestStatus.entregado) {
    return lines.every((l) => l.pedidoEntregadoYPagado)
        ? 'Compra completada. Tus documentos siguen disponibles.'
        : 'Pedido entregado. Revisa el estado del pago.';
  }
  if (r.status == TransactionRequestStatus.enTransito ||
      r.status == TransactionRequestStatus.enviado) {
    return viewer == AppHomeRole.aliado
        ? 'Confirma la recepción cuando llegue tu pedido.'
        : 'Consulta el seguimiento y la confirmación de entrega.';
  }
  if (viewer == AppHomeRole.aliado) {
    if (r.status == TransactionRequestStatus.pendiente) {
      return 'Esperando la confirmación del proveedor.';
    }
    if (r.status == TransactionRequestStatus.pedidoListo) {
      return 'Revisa cómo recibirás tu pedido.';
    }
    return lines.any((l) => l.hasProveedorFactura)
        ? 'Revisa la factura y el estado del pago.'
        : 'Esperando la factura del proveedor.';
  }
  return viewer == AppHomeRole.importador
      ? 'Revisa los productos y el siguiente paso del envío.'
      : 'Revisa las gestiones pendientes de este pedido.';
}
