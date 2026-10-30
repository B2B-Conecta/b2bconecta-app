import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'aliado_order_grouping.dart';
import 'importer_order_date.dart';
import 'order_card_direct_summary.dart';
import 'order_status_label.dart';
import 'transaction_request_model.dart';
import 'transaction_request_status.dart';
import 'order_list_colors.dart';

/// Read-only projection: amounts always retain the order's agreed currency.
class OrderListEntry {
  OrderListEntry(this.lines);
  final List<TransactionRequestModel> lines;
  String get key => checkoutGroupExpandKey(lines);
  String get reference {
    final id = lines.first.checkoutGroupId?.trim();
    final value = id == null || id.isEmpty ? lines.first.id : id;
    return '#${value.substring(0, value.length < 8 ? value.length : 8).toUpperCase()}';
  }

  List<OrderCardProductPeek> get products =>
      orderCardProductPeeks(lines: lines);
  String get title =>
      products.isEmpty ? 'Productos del pedido' : products.first.name;
  String get provider {
    final names = lines
        .map((l) => l.ownerBusinessName?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    return names.isEmpty
        ? 'Proveedor'
        : names.length == 1
            ? names.first
            : '${names.first} +${names.length - 1}';
  }

  int get quantity => lines.fold(0, (sum, l) => sum + l.cantidad);
  String get date {
    final value = ImporterOrderDate.fechaGrupoParaFiltro(lines);
    return value == null
        ? 'Sin fecha'
        : ImporterOrderDate.formatFechaPedido(value);
  }

  String get amount =>
      '${formatRefAmount(lines.fold<double>(0, (sum, l) => sum + l.precioTotal))} ${orderAmountCurrency(lines)}';
  String? get bolivares => orderAmountCurrency(lines) == 'REF' &&
          lines.every((l) => l.precioTotalBsUi != null)
      ? formatBsLabel(
          lines.fold<double>(0, (sum, l) => sum + l.precioTotalBsUi!))
      : null;
  bool get needsAttention =>
      lines.any((l) => l.qtyAdjustmentPendienteAliado || l.esPedidoMoroso);
  String get status {
    if (lines.any((l) => l.qtyAdjustmentPendienteAliado)) {
      return 'Revisar cantidad';
    }
    if (lines.any((l) => l.esPedidoMoroso)) return 'Pago pendiente';
    if (lines.every((l) => l.pedidoEntregadoYPagado)) return 'Completado';
    if (lines.any((l) => l.status != lines.first.status)) {
      return 'Varios estados';
    }
    return orderStatusLabel(lines.first.status);
  }

  Color statusColor(BuildContext context) {
    if (needsAttention) return Theme.of(context).colorScheme.error;
    if (lines.every((l) => l.status == TransactionRequestStatus.rechazado)) {
      return OrderListColors.of(context).secondary;
    }
    if (lines.every((l) => l.status == TransactionRequestStatus.entregado)) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.green.shade300
          : Color.lerp(AppColors.successGreen, AppColors.black, .06)!;
    }
    if (lines.every((l) => l.status == TransactionRequestStatus.pendiente)) {
      return Theme.of(context).brightness == Brightness.dark
          ? AppColors.warningAmberOnDark
          : AppColors.warningAmber;
    }
    return OrderListColors.of(context).accent;
  }

  int? get shippingPhase {
    if (needsAttention || lines.any((l) => l.status != lines.first.status)) {
      return null;
    }
    final phase = orderShippingPhase(lines.first.status);
    return phase < 0 ? null : phase;
  }

  IconData get statusIcon {
    if (needsAttention) return Icons.info_outline;
    if (lines.any((l) => l.status != lines.first.status)) {
      return Icons.swap_horiz;
    }
    return switch (lines.first.status) {
      TransactionRequestStatus.pendiente => Icons.schedule_outlined,
      TransactionRequestStatus.rechazado => Icons.block_outlined,
      TransactionRequestStatus.entregado => Icons.check_circle_outline,
      TransactionRequestStatus.enTransito ||
      TransactionRequestStatus.enviado =>
        Icons.local_shipping_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }
}

int orderShippingPhase(String status) => switch (status) {
      TransactionRequestStatus.pendiente => 0,
      TransactionRequestStatus.aprobadoAdmin ||
      TransactionRequestStatus.enPreparacion ||
      TransactionRequestStatus.pedidoListo =>
        1,
      TransactionRequestStatus.enTransito ||
      TransactionRequestStatus.enviado =>
        2,
      TransactionRequestStatus.entregado => 3,
      _ => -1,
    };
