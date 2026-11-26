import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/desktop_workflow.dart';
import 'package:motolink_pro_app/core/widgets/b2b_header_title.dart';
import '../../../app/theme/b2b_theme_extension.dart';
import '../../../core/utils/ves_amount_format.dart';
import '../../../core/utils/app_date_format.dart';
import 'order_product_thumb.dart';
import 'transaction_request_model.dart';

const mobileOrderActionBlue = Color(0xFF0047E1);

String mobileOrderActionDate(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final today = DateUtils.dateOnly((now ?? DateTime.now()).toLocal());
  final day = DateUtils.dateOnly(local);
  final label = day == today
      ? 'Hoy'
      : day == DateUtils.addDaysToDate(today, -1)
          ? 'Ayer'
          : formatEsShortDate(local);
  return '$label · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String mobileOrderReference(List<TransactionRequestModel> lines) {
  final line = lines.first;
  final value = line.checkoutGroupId ?? line.originalCheckoutGroupId ?? line.id;
  return '#${value.substring(0, value.length < 8 ? value.length : 8).toUpperCase()}';
}

PreferredSizeWidget mobileOrderActionBar(BuildContext context, String title,
        {VoidCallback? onBack}) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu
        ? desktopWorkflowAppBar(context, title, onBack: onBack)
        : AppBar(
            backgroundColor: mobileOrderActionBlue,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            toolbarHeight:
                MediaQuery.textScalerOf(context).scale(18) > 23 ? 96 : 72,
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(24))),
            leading: BackButton(onPressed: onBack),
            title: B2bHeaderTitle(
              title: Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
          );

class MobileOrderActionPanel extends StatelessWidget {
  const MobileOrderActionPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: B2BThemeExtension.of(context).surfaceCard,
          borderRadius: BorderRadius.circular(16)),
      child: child);
}

class MobileOrderActionNotice extends StatelessWidget {
  const MobileOrderActionNotice(this.text, {super.key, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: error ? theme.warningBg : theme.brandContainer,
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(error ? Icons.error_outline : Icons.info_outline,
              size: 20, color: error ? theme.warningFg : theme.textPrimary),
          const SizedBox(width: 9),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: theme.textPrimary, fontSize: 13, height: 1.35))),
        ]));
  }
}

class MobileOrderActionProducts extends StatelessWidget {
  const MobileOrderActionProducts(
      {super.key, required this.lines, this.cancelled = false, this.footer});
  final List<TransactionRequestModel> lines;
  final bool cancelled;
  final Widget? footer;
  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return MobileOrderActionPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(mobileOrderReference(lines),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      for (final line in lines) ...[
        const SizedBox(height: 12),
        Text(line.ownerBusinessName ?? 'Proveedor',
            style: TextStyle(fontSize: 13, color: theme.textSecondary)),
        const SizedBox(height: 7),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          OrderProductThumb(size: 64, url: line.productImageUrls.firstOrNull),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(line.productName ?? 'Producto',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    '${line.cantidad} ${line.cantidad == 1 ? 'unidad' : 'unidades'} · ${formatRefAmount(line.precioTotal)} ${line.metodoPagoMoneda == 'DIVISAS' ? 'USD' : 'REF'}',
                    style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                const SizedBox(height: 6),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: cancelled
                            ? Theme.of(context)
                                .colorScheme
                                .error
                                .withOpacity(.10)
                            : theme.warningBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        cancelled
                            ? 'Cancelado'
                            : line.statusLabelEs(aliadoViewer: true),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cancelled
                                ? Theme.of(context).colorScheme.error
                                : theme.textPrimary))),
                if (!cancelled && line.atEntregado != null)
                  Text('Entregado el ${formatEsShortDate(line.atEntregado!)}',
                      style:
                          TextStyle(fontSize: 12, color: theme.textSecondary)),
              ])),
        ]),
      ],
      if (footer != null) ...[const Divider(height: 24), footer!],
    ]));
  }
}
