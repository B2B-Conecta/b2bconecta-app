import 'package:flutter/material.dart';
import 'order_list_colors.dart';
import 'order_list_entry.dart';
import 'order_list_row.dart';
import 'transaction_request_model.dart';

/// A purchase overview, with one total and the next action kept together.
class OrderDetailOverview extends StatelessWidget {
  const OrderDetailOverview(
      {super.key,
      required this.lines,
      required this.nextStep,
      required this.chatAction,
      this.cancelAction});
  final List<TransactionRequestModel> lines;
  final String nextStep;
  final Widget chatAction;
  final Widget? cancelAction;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final entry = OrderListEntry(lines);
    final count = entry.products.length;
    final identity =
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: colors.accent.withOpacity(.09),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.shopping_bag_outlined,
              color: colors.accent, size: 23)),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '$count ${count == 1 ? 'repuesto' : 'repuestos'} · ${entry.quantity} ${entry.quantity == 1 ? 'unidad' : 'unidades'}',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: colors.ink)),
        const SizedBox(height: 5),
        Text(entry.date,
            style: TextStyle(fontSize: 12, color: colors.secondary)),
      ])),
    ]);
    final amount =
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(entry.amount,
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -.4,
              color: colors.ink)),
      if (entry.bolivares != null) ...[
        const SizedBox(height: 4),
        Text(entry.bolivares!,
            style: TextStyle(fontSize: 12, color: colors.secondary)),
      ],
    ]);
    final note = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(entry.needsAttention ? Icons.info_outline : Icons.schedule_outlined,
          size: 17,
          color: entry.needsAttention
              ? Theme.of(context).colorScheme.error
              : colors.accent),
      const SizedBox(width: 8),
      Expanded(
          child: Text(nextStep,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: entry.needsAttention
                      ? Theme.of(context).colorScheme.error
                      : colors.secondary))),
    ]);
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: chatAction),
      if (cancelAction != null) ...[const SizedBox(width: 4), cancelAction!],
    ]);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border)),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 650 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
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
                ]),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: colors.border)),
              if (compact) ...[
                note,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ] else
                Row(children: [
                  Expanded(child: note),
                  const SizedBox(width: 20),
                  actions
                ]),
            ]);
      }),
    );
  }
}
