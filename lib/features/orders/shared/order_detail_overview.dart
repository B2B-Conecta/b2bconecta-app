import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'order_list_colors.dart';
import 'order_list_entry.dart';
import 'order_list_row.dart';
import 'transaction_request_model.dart';

/// Cabecera del detalle: ID, fecha, monto REF/USD + Bs BCV y siguiente paso.
class OrderDetailOverview extends StatelessWidget {
  const OrderDetailOverview(
      {super.key,
      required this.lines,
      required this.nextStep,
      required this.chatAction,
      this.viewerRole = AppHomeRole.aliado,
      this.actionsInHeader = false,
      this.compactRetailer = false,
      this.cancelAction});
  final List<TransactionRequestModel> lines;
  final String nextStep;
  final Widget chatAction;
  final Widget? cancelAction;
  final AppHomeRole viewerRole;
  final bool actionsInHeader;
  final bool compactRetailer;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final entry = OrderListEntry(lines, viewerRole: viewerRole);
    if (compactRetailer) return _retailerSummary(context, entry, OrderListColors.of(context));
    final count = entry.products.length;
    final identity =
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: theme.brandContainer,
              borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: LucideIcon(
            LucideGlyph.shoppingBag,
            color: theme.brand,
            size: 20,
          )),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            entry.reference,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary)),
        const SizedBox(height: 3),
        Text(
            '$count ${count == 1 ? 'repuesto' : 'repuestos'} · ${entry.quantity} ${entry.quantity == 1 ? 'unidad' : 'unidades'}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary)),
        const SizedBox(height: 3),
        Text(entry.date,
            style: TextStyle(fontSize: 12, color: theme.textMuted)),
      ])),
    ]);
    final amount =
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(entry.amount,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -.3,
              color: theme.textPrimary)),
      if (entry.bolivares != null) ...[
        const SizedBox(height: 4),
        Text(entry.bolivares!,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary)),
      ] else ...[
        const SizedBox(height: 4),
        Text('Bs —',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.textMuted)),
      ],
    ]);
    final note = nextStep.isEmpty
        ? const SizedBox.shrink()
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LucideIcon(
                entry.needsAttention
                    ? LucideGlyph.circleAlert
                    : LucideGlyph.clipboardCheck,
                size: 16,
                color: entry.needsAttention
                    ? Theme.of(context).colorScheme.error
                    : theme.brand),
            const SizedBox(width: 8),
            Expanded(
                child: Text(nextStep,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: entry.needsAttention
                            ? Theme.of(context).colorScheme.error
                            : theme.textSecondary))),
          ]);
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: chatAction),
      if (cancelAction != null) ...[const SizedBox(width: 4), cancelAction!],
    ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
          color: theme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderSubtle)),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 650 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                if (actionsInHeader)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: identity),
                    const SizedBox(width: 8),
                    actions,
                  ])
                else
                  identity,
                const SizedBox(height: 14),
                if (constraints.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 20)
                  Row(children: [
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerLeft, child: amount)),
                    const SizedBox(width: 12),
                    Flexible(child: OrderStatusTag(entry: entry))
                  ])
                else ...[
                  Align(
                      alignment: Alignment.centerLeft,
                      child: OrderStatusTag(entry: entry)),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: amount),
                ],
              ] else
                Row(children: [
                  Expanded(flex: 3, child: identity),
                  const SizedBox(width: 20),
                  Expanded(
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: OrderStatusTag(entry: entry))),
                  const SizedBox(width: 28),
                  Expanded(flex: 2, child: amount),
                  if (actionsInHeader) ...[
                    const SizedBox(width: 12),
                    actions,
                  ],
                ]),
              if (!actionsInHeader || nextStep.isNotEmpty) ...[
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: theme.borderSubtle)),
                if (actionsInHeader)
                  note
                else if (nextStep.isEmpty)
                  Align(alignment: Alignment.centerRight, child: actions)
                else if (compact) ...[
                  note,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actions),
                ] else
                  Row(children: [
                    Expanded(child: note),
                    const SizedBox(width: 20),
                    actions
                  ]),
              ],
            ]);
      }),
    );
  }

  Widget _retailerSummary(
    BuildContext context,
    OrderListEntry entry,
    OrderListColors colors,
  ) {
    final meta = TextStyle(fontSize: 12, color: colors.secondary, height: 1.25);
    final count = entry.products.length;
    final title = count > 1 ? '${entry.title} y ${count - 1} más' : entry.title;
    final quantity =
        '${entry.quantity} ${entry.quantity == 1 ? 'unidad' : 'unidades'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
              color: colors.detailSurface,
              borderRadius: BorderRadius.circular(15)),
          padding: const EdgeInsets.fromLTRB(9, 2, 9, 9),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                chatAction,
                if (cancelAction != null) cancelAction!,
              ]),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                OrderThumbnail(entry: entry, size: 60),
                const SizedBox(width: 9),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: colors.ink)),
                    const SizedBox(height: 2),
                    Text('$quantity · ${entry.date}', style: meta),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        OrderStatusTag(entry: entry, compact: true),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(entry.amount,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: colors.ink)),
                            if (entry.bolivares case final amount?)
                              Text(amount, style: meta),
                          ],
                        ),
                      ],
                    ),
                  ],
                )),
              ]),
            ],
          ),
        ),
        if (nextStep.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
            child: Text(nextStep,
                style: meta.copyWith(
                    color: entry.needsAttention
                        ? Theme.of(context).colorScheme.error
                        : colors.secondary)),
          ),
      ],
    );
  }
}
